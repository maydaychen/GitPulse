import Foundation

public struct GiteaClient: Sendable {
    public let baseURL: String
    public let credentials: StoredCredentials
    public let transport: HTTPTransport

    public init(
        baseURL: String,
        credentials: StoredCredentials,
        transport: HTTPTransport = URLSessionHTTPTransport()
    ) {
        self.baseURL = baseURL
        self.credentials = credentials
        self.transport = transport
    }

    public func sendRaw(
        method: String = "GET",
        endpoint: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        additionalHeaders: [String: String] = [:],
        timeout: TimeInterval = 20
    ) async throws -> HTTPResponseData {
        let url = try GiteaURLBuilder.apiURL(
            baseURLString: baseURL,
            endpointPath: endpoint,
            queryItems: queryItems
        )
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if !credentials.patToken.isEmpty {
            request.setValue("token \(credentials.patToken)", forHTTPHeaderField: "Authorization")
        }
        for (key, value) in credentials.customHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        for (key, value) in additionalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let response = try await transport.perform(request, timeout: timeout)
        if response.statusCode == 401 {
            throw GiteaClientError.unauthorized
        }
        if response.statusCode == 413 {
            throw GiteaClientError.payloadTooLarge(
                limitHint: "Nginx client_max_body_size 限制超限，请在反代配置调大上传体积"
            )
        }
        guard (200...299).contains(response.statusCode) else {
            let text = String(data: response.body, encoding: .utf8) ?? ""
            throw GiteaClientError.httpStatus(response.statusCode, String(text.prefix(160)))
        }
        return response
    }

    public func fetchJSON<T: Decodable>(
        method: String = "GET",
        endpoint: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> T {
        let response = try await sendRaw(method: method, endpoint: endpoint, queryItems: queryItems, body: body)
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: response.body)
        } catch {
            throw GiteaClientError.decodingFailure(error.localizedDescription)
        }
    }

    // MARK: - Pulse & User

    public func fetchVersion() async throws -> String {
        struct VersionDTO: Decodable { let version: String }
        let dto: VersionDTO = try await fetchJSON(endpoint: "/version")
        return dto.version
    }

    public func fetchCurrentUserLogin() async throws -> String {
        struct UserDTO: Decodable { let login: String }
        let dto: UserDTO = try await fetchJSON(endpoint: "/user")
        return dto.login
    }

    public func fetchHeatmap(username: String) async throws -> [HeatmapDay] {
        struct HeatmapItemDTO: Decodable {
            let timestamp: TimeInterval
            let contributions: Int
        }
        let encodedUser = GiteaURLBuilder.encodedSegment(username)
        let items: [HeatmapItemDTO] = try await fetchJSON(endpoint: "/users/\(encodedUser)/heatmap")
        return items.enumerated().map { index, item in
            HeatmapDay(
                id: "hm-\(index)-\(Int(item.timestamp))",
                date: Date(timeIntervalSince1970: item.timestamp),
                contributions: item.contributions
            )
        }
    }

    public func fetchRepositories(
        page: Int = 1,
        limit: Int = 50,
        currentUsername: String? = nil
    ) async throws -> [RepositorySummary] {
        let dtos: [RepoDTO] = try await fetchJSON(
            endpoint: "/user/repos",
            queryItems: [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
        return dtos.map { $0.toRepositorySummary(currentUsername: currentUsername) }
    }

    public func fetchAllAccessibleRepositories(
        currentUsername: String? = nil,
        maxPages: Int = 4
    ) async throws -> [RepositorySummary] {
        let pageSize = 50
        var all: [RepositorySummary] = []
        var seenIDs = Set<String>()
        for page in 1...maxPages {
            let batch = try await fetchRepositories(page: page, limit: pageSize, currentUsername: currentUsername)
            for repo in batch where seenIDs.insert(repo.id).inserted { all.append(repo) }
            if batch.count < pageSize { break }
        }
        return all.sorted { $0.updatedAtText > $1.updatedAtText }
    }

    public func fetchRepository(
        owner: String,
        repo: String,
        currentUsername: String? = nil
    ) async throws -> RepositorySummary {
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        let dto: RepoDTO = try await fetchJSON(endpoint: "/repos/\(o)/\(r)")
        return dto.toRepositorySummary(currentUsername: currentUsername)
    }

    public func fetchPullRequests(owner: String, repo: String) async throws -> [PullRequestDetail] {
        struct BranchRefDTO: Decodable { let label: String?; let ref: String?; let sha: String? }
        struct UserRefDTO: Decodable { let login: String }
        struct PRDTO: Decodable {
            let id: Int
            let number: Int
            let title: String
            let state: String
            let mergeable: Bool?
            let additions: Int?
            let deletions: Int?
            let user: UserRefDTO
            let head: BranchRefDTO
            let base: BranchRefDTO
        }
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        let dtos: [PRDTO] = try await fetchJSON(endpoint: "/repos/\(o)/\(r)/pulls")
        return dtos.map { dto in
            PullRequestDetail(
                id: "pr-\(owner)-\(repo)-\(dto.number)",
                number: dto.number,
                repoFullName: "\(owner)/\(repo)",
                title: dto.title,
                author: dto.user.login,
                headBranch: dto.head.ref ?? dto.head.label ?? "feat",
                headSHA: dto.head.sha,
                baseBranch: dto.base.ref ?? dto.base.label ?? "main",
                state: PRState(rawValue: dto.state.lowercased()) ?? .open,
                mergeable: dto.mergeable ?? false,
                additions: dto.additions ?? 0,
                deletions: dto.deletions ?? 0
            )
        }
    }

    // MARK: - Activity Feeds

    /// 拉取指定用户的实例动态流。
    public func fetchActivityFeeds(username: String, limit: Int = 20) async throws -> [ActivityEvent] {
        let encodedUser = GiteaURLBuilder.encodedSegment(username)
        return try await fetchFeeds(
            endpoint: "/users/\(encodedUser)/activities/feeds",
            prefix: "user-act",
            limit: limit
        )
    }

    /// 拉取指定组织的实例动态流。
    public func fetchOrgActivityFeeds(org: String, limit: Int = 10) async throws -> [ActivityEvent] {
        let encodedOrg = GiteaURLBuilder.encodedSegment(org)
        return try await fetchFeeds(
            endpoint: "/orgs/\(encodedOrg)/activities/feeds",
            prefix: "org-\(encodedOrg)",
            limit: limit
        )
    }

    /// 当动态接口返回空列表或受限时，基于开放合并请求与近期更新仓库构造兜底动态。
    public static func buildFallbackActivities(
        repositories: [RepositorySummary],
        pullRequests: [PullRequestDetail]
    ) -> [ActivityEvent] {
        guard !repositories.isEmpty || !pullRequests.isEmpty else { return [] }
        var events: [ActivityEvent] = pullRequests
            .filter { $0.state == .open }
            .prefix(4)
            .map { pr in
                ActivityEvent(
                    id: "fallback-pr-\(pr.id)",
                    actor: pr.author.isEmpty ? "system" : pr.author,
                    actionLabel: "待审合并请求 #\(pr.number) \(pr.title)",
                    repoFullName: pr.repoFullName,
                    refText: pr.headBranch,
                    timestampText: "开放中",
                    deepLink: "teapulse://pull/\(pr.repoFullName)/\(pr.number)"
                )
            }
        let sortedRepos = repositories.sorted { lhs, rhs in
            if lhs.updatedAtText == rhs.updatedAtText { return false }
            return lhs.updatedAtText > rhs.updatedAtText
        }
        for repo in sortedRepos.prefix(8) {
            events.append(ActivityEvent(
                id: "fallback-repo-\(repo.id)",
                actor: repo.owner.isEmpty ? "system" : repo.owner,
                actionLabel: repo.isMirror ? "镜像同步仓库" : "仓库近期更新",
                repoFullName: repo.fullName,
                refText: repo.defaultBranch,
                timestampText: repo.updatedAtText.isEmpty ? "近期" : repo.updatedAtText,
                deepLink: "teapulse://repo/\(repo.fullName)"
            ))
        }
        return Array(events.prefix(10))
    }

    public func mergeActivityRepositories(
        activities: [ActivityEvent], into repositories: [RepositorySummary],
        currentUsername: String? = nil, maxFetch: Int = 8
    ) async -> [RepositorySummary] {
        var seen = Set(repositories.map { $0.fullName.lowercased() })
        var targets: [(String, String)] = []
        for act in activities where targets.count < maxFetch {
            let parts = act.repoFullName.split(separator: "/").map(String.init)
            if parts.count == 2, seen.insert(act.repoFullName.lowercased()).inserted {
                targets.append((parts[0], parts[1]))
            }
        }
        let fetched = await boundedConcurrentMap(targets, maxConcurrency: 6) {
            try? await self.fetchRepository(owner: $0.0, repo: $0.1, currentUsername: currentUsername)
        }
        return repositories + fetched.compactMap { $0 }
    }

    private func fetchFeeds(endpoint: String, prefix: String, limit: Int) async throws -> [ActivityEvent] {
        let dtos: [ActivityFeedDTO] = try await fetchJSON(
            endpoint: endpoint,
            queryItems: [URLQueryItem(name: "limit", value: "\(limit)")]
        )
        return dtos.enumerated().map { index, dto in
            dto.toActivityEvent(fallbackID: "\(prefix)-\(index)")
        }
    }
}

private enum ActivityOpTypeDTO: Decodable {
    case string(String)
    case int(Int)

    private static let legacyIntMap: [Int: String] = [
        1: "create_repo", 2: "rename_repo", 3: "star_repo", 4: "watch_repo",
        5: "commit_repo", 6: "create_issue", 7: "create_pull_request", 8: "transfer_repo",
        9: "push_tag", 10: "comment_issue", 11: "merge_pull_request", 12: "close_issue",
        13: "reopen_issue", 14: "close_pull_request", 15: "reopen_pull_request",
        16: "delete_tag", 17: "delete_branch", 18: "mirror_sync_push",
        19: "mirror_sync_create", 20: "mirror_sync_delete", 21: "approve_pull_request",
        22: "reject_pull_request", 23: "comment_pull", 24: "publish_release",
        27: "auto_merge_pull_request"
    ]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .string(str)
        } else if let num = try? container.decode(Int.self) {
            self = .int(num)
        } else {
            self = .string("")
        }
    }

    var normalizedKey: String {
        switch self {
        case .string(let s): return s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        case .int(let n): return Self.legacyIntMap[n] ?? "\(n)"
        }
    }
}

private struct ActivityFeedDTO: Decodable {
    struct UserDTO: Decodable {
        let login: String?
        let username: String?
    }
    struct OwnerDTO: Decodable {
        let login: String?
    }
    struct RepoDTO: Decodable {
        let name: String?
        let fullName: String?
        let owner: OwnerDTO?
    }

    let id: Int64?
    let actUser: UserDTO?
    let opType: ActivityOpTypeDTO?
    let content: String?
    let refName: String?
    let created: String?
    let repo: RepoDTO?

    func toActivityEvent(fallbackID: String) -> ActivityEvent {
        let actor = Self.firstNonEmpty([actUser?.login, actUser?.username, repo?.owner?.login]) ?? "system"
        let fullName: String
        if let explicit = repo?.fullName?.trimmingCharacters(in: .whitespacesAndNewlines), !explicit.isEmpty {
            fullName = explicit
        } else if let o = repo?.owner?.login, !o.isEmpty, let r = repo?.name, !r.isEmpty {
            fullName = "\(o)/\(r)"
        } else {
            fullName = ""
        }
        let cleanedRef = Self.cleanRef(refName)
        let opKey = opType?.normalizedKey ?? ""
        let (label, targetNumber, isPull) = Self.describeAction(opKey: opKey, content: content, refText: cleanedRef)
        let deepLink: String
        if fullName.split(separator: "/").count == 2 {
            deepLink = (isPull && targetNumber != nil)
                ? "teapulse://pull/\(fullName)/\(targetNumber!)"
                : "teapulse://repo/\(fullName)"
        } else {
            deepLink = ""
        }
        return ActivityEvent(
            id: id.map { "act-\($0)" } ?? fallbackID,
            actor: actor,
            actionLabel: label,
            repoFullName: fullName,
            refText: cleanedRef,
            timestampText: Self.formatTimestamp(created),
            deepLink: deepLink
        )
    }

    private static func firstNonEmpty(_ values: [String?]) -> String? {
        for value in values {
            if let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private static func cleanRef(_ raw: String?) -> String {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return ""
        }
        for prefix in ["refs/heads/", "refs/tags/"] where trimmed.hasPrefix(prefix) {
            return String(trimmed.dropFirst(prefix.count))
        }
        return trimmed
    }

    private static func formatTimestamp(_ raw: String?) -> String {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return ""
        }
        if trimmed.count >= 16, trimmed[trimmed.index(trimmed.startIndex, offsetBy: 10)] == "T" {
            let start = trimmed.index(trimmed.startIndex, offsetBy: 5)
            let mid = trimmed.index(trimmed.startIndex, offsetBy: 10)
            let timeStart = trimmed.index(trimmed.startIndex, offsetBy: 11)
            let end = trimmed.index(trimmed.startIndex, offsetBy: 16)
            return "\(trimmed[start..<mid]) \(trimmed[timeStart..<end])"
        }
        return String(trimmed.prefix(10))
    }

    private static func describeAction(
        opKey: String, content: String?, refText: String
    ) -> (label: String, number: Int?, isPull: Bool) {
        let (itemNumber, itemTitle) = parsePipeContent(content)
        let suffix = itemTitle.isEmpty ? "" : " \(itemTitle)"
        switch opKey {
        case "commit_repo":
            if let msg = parseCommitMessage(content) { return ("推送提交：\(msg)", nil, false) }
            return ("推送了代码提交", nil, false)
        case "create_pull_request":
            return (itemNumber.map { "发起合并请求 #\($0)\(suffix)" } ?? "发起合并请求", itemNumber, true)
        case "merge_pull_request", "auto_merge_pull_request":
            return (itemNumber.map { "合并了合并请求 #\($0)\(suffix)" } ?? "合并了合并请求", itemNumber, true)
        case "close_pull_request":
            return (itemNumber.map { "关闭合并请求 #\($0)\(suffix)" } ?? "关闭合并请求", itemNumber, true)
        case "reopen_pull_request":
            return (itemNumber.map { "重新打开合并请求 #\($0)\(suffix)" } ?? "重新打开合并请求", itemNumber, true)
        case "approve_pull_request":
            return (itemNumber.map { "批准合并请求 #\($0)" } ?? "批准合并请求", itemNumber, true)
        case "reject_pull_request":
            return (itemNumber.map { "要求修改合并请求 #\($0)" } ?? "要求修改合并请求", itemNumber, true)
        case "comment_pull":
            return (itemNumber.map { "评论合并请求 #\($0)" } ?? "评论合并请求", itemNumber, true)
        case "create_issue":
            return (itemNumber.map { "新建议题 #\($0)\(suffix)" } ?? "新建议题", itemNumber, false)
        case "close_issue":
            return (itemNumber.map { "关闭议题 #\($0)\(suffix)" } ?? "关闭议题", itemNumber, false)
        case "reopen_issue":
            return (itemNumber.map { "重新打开议题 #\($0)\(suffix)" } ?? "重新打开议题", itemNumber, false)
        case "comment_issue":
            return (itemNumber.map { "评论议题 #\($0)" } ?? "评论议题", itemNumber, false)
        case "create_repo": return ("创建了仓库", nil, false)
        case "rename_repo": return ("重命名了仓库", nil, false)
        case "transfer_repo": return ("转移了仓库", nil, false)
        case "star_repo": return ("星标了仓库", nil, false)
        case "watch_repo": return ("关注了仓库", nil, false)
        case "push_tag": return ("推送了标签", nil, false)
        case "delete_tag": return ("删除了标签", nil, false)
        case "delete_branch": return ("删除了分支", nil, false)
        case "mirror_sync_push": return ("镜像同步推送", nil, false)
        case "mirror_sync_create": return ("镜像同步创建分支", nil, false)
        case "mirror_sync_delete": return ("镜像同步删除分支", nil, false)
        case "publish_release": return ("发布了新版本", nil, false)
        default: return (opKey.isEmpty ? "实例动态" : opKey, nil, false)
        }
    }

    private static func parsePipeContent(_ raw: String?) -> (Int?, String) {
        guard let raw, !raw.isEmpty else { return (nil, "") }
        let parts = raw.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2, let num = Int(parts[0].trimmingCharacters(in: .whitespacesAndNewlines)) {
            let title = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            return (num, title)
        }
        return (nil, raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func parseCommitMessage(_ raw: String?) -> String? {
        guard let data = raw?.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let commits = (json["Commits"] ?? json["commits"]) as? [[String: Any]],
              let rawMessage = (commits.first?["Message"] ?? commits.first?["message"]) as? String else {
            return nil
        }
        let firstLine = rawMessage
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        return firstLine
    }
}

internal struct RepoDTO: Decodable {
    struct OwnerDTO: Decodable { let login: String; let type: String? }
    let id: Int
    let name, fullName: String
    let owner: OwnerDTO
    let defaultBranch, mirrorInterval, cloneUrl, sshUrl, updatedAt: String?
    let starsCount, openPrCounter, openIssuesCount: Int?
    let mirror: Bool?

    func toRepositorySummary(currentUsername: String?) -> RepositorySummary {
        let isMirror = mirror ?? false
        let normalizedUser = currentUsername?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isOrg = owner.type?.lowercased() == "organization"
            || (normalizedUser.map { !$0.isEmpty && owner.login.lowercased() != $0 } ?? false)
        return RepositorySummary(
            id: "\(id)", owner: owner.login, name: name, fullName: fullName,
            scope: isMirror ? .mirror : (isOrg ? .org : .personal),
            isOrganizationOwned: isOrg,
            isStarred: false, isMirror: isMirror,
            mirrorInterval: mirrorInterval, lastMirrorSyncText: nil, defaultBranch: defaultBranch ?? "main",
            stars: starsCount ?? 0, openPRCount: openPrCounter ?? 0, openIssueCount: openIssuesCount ?? 0,
            updatedAtText: String((updatedAt ?? "").prefix(10)), cloneURL: cloneUrl ?? "", sshURL: sshUrl ?? "",
            readmeMarkdown: "README 暂未加载"
        )
    }
}
