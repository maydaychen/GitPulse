import Foundation

extension GiteaClient {
    // MARK: - Pull Requests & Repo Contents

    private struct RepoContentDTO: Decodable {
        let name: String
        let path: String
        let sha: String
        let type: String
        let size: Int?
        let content: String?
        let encoding: String?
    }

    private func repoContentsEndpoint(owner: String, repo: String, path: String) -> String {
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        let segments = path.split(separator: "/").map { GiteaURLBuilder.encodedSegment(String($0)) }
        if segments.isEmpty {
            return "/repos/\(o)/\(r)/contents"
        }
        return "/repos/\(o)/\(r)/contents/\(segments.joined(separator: "/"))"
    }

    private func decodeContentText(_ dto: RepoContentDTO) -> String {
        let raw = dto.content ?? ""
        guard dto.encoding == nil || dto.encoding == "base64" else { return raw }
        guard let data = Data(base64Encoded: raw, options: [.ignoreUnknownCharacters]) else { return raw }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        return "（二进制或非 UTF-8 文件，\(dto.size ?? data.count) B）"
    }

    public func fetchRepoContents(
        owner: String,
        repo: String,
        path: String = "",
        ref: String? = nil
    ) async throws -> [RepoFileEntry] {
        let endpoint = repoContentsEndpoint(owner: owner, repo: repo, path: path)
        let query = ref.map { [URLQueryItem(name: "ref", value: $0)] } ?? []
        let dtos: [RepoContentDTO] = try await fetchJSON(endpoint: endpoint, queryItems: query)
        return dtos.map { dto in
            RepoFileEntry(
                id: dto.path.isEmpty ? dto.name : dto.path,
                name: dto.name,
                path: dto.path,
                isDirectory: dto.type == "dir",
                sizeBytes: dto.size ?? 0,
                sha: dto.sha,
                content: dto.content != nil ? decodeContentText(dto) : nil
            )
        }
        .sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory }
            return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }

    public func fetchRepoFileContent(
        owner: String,
        repo: String,
        path: String,
        ref: String? = nil
    ) async throws -> String {
        let endpoint = repoContentsEndpoint(owner: owner, repo: repo, path: path)
        let query = ref.map { [URLQueryItem(name: "ref", value: $0)] } ?? []
        let dto: RepoContentDTO = try await fetchJSON(endpoint: endpoint, queryItems: query)
        return decodeContentText(dto)
    }

    public func fetchIssues(owner: String, repo: String) async throws -> [IssueItem] {
        struct UserRefDTO: Decodable { let login: String }
        struct LabelDTO: Decodable { let name: String }
        struct IssueDTO: Decodable {
            let number: Int
            let title: String
            let state: String
            let user: UserRefDTO?
            let labels: [LabelDTO]?
            let updatedAt: String?
        }
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        let dtos: [IssueDTO] = try await fetchJSON(
            endpoint: "/repos/\(o)/\(r)/issues",
            queryItems: [
                URLQueryItem(name: "type", value: "issues"),
                URLQueryItem(name: "state", value: "open")
            ]
        )
        return dtos.map { dto in
            IssueItem(
                id: "issue-\(owner)-\(repo)-\(dto.number)",
                number: dto.number,
                title: dto.title,
                state: dto.state,
                author: dto.user?.login ?? "",
                labels: (dto.labels ?? []).map(\.name),
                blockedByNumbers: [],
                updatedAtText: String((dto.updatedAt ?? "").prefix(10))
            )
        }
    }

    public func fetchReleases(owner: String, repo: String) async throws -> [ReleaseItem] {
        struct AssetDTO: Decodable { let name: String }
        struct ReleaseDTO: Decodable {
            let id: Int
            let tagName: String?
            let name: String?
            let publishedAt: String?
            let createdAt: String?
            let prerelease: Bool?
            let assets: [AssetDTO]?
        }
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        let dtos: [ReleaseDTO] = try await fetchJSON(endpoint: "/repos/\(o)/\(r)/releases")
        return dtos.map { dto in
            let fallbackTag = dto.tagName ?? ""
            let title = (dto.name?.isEmpty == false ? dto.name : nil) ?? fallbackTag
            return ReleaseItem(
                id: "rel-\(dto.id)",
                tagName: fallbackTag,
                title: title,
                publishedAtText: String((dto.publishedAt ?? dto.createdAt ?? "").prefix(10)),
                assetNames: (dto.assets ?? []).map(\.name),
                isPrerelease: dto.prerelease ?? false
            )
        }
    }

    public func fetchWebhooks(owner: String, repo: String) async throws -> [WebhookConfig] {
        struct HookDTO: Decodable {
            let id: Int
            let config: [String: String]?
            let url: String?
            let events: [String]?
            let active: Bool?
        }
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        let dtos: [HookDTO] = try await fetchJSON(endpoint: "/repos/\(o)/\(r)/hooks")
        return dtos.map { dto in
            WebhookConfig(
                id: "hook-\(dto.id)",
                numericID: dto.id,
                targetURL: dto.config?["url"] ?? dto.url ?? "",
                events: dto.events ?? [],
                isActive: dto.active ?? true,
                lastStatusCode: 0,
                deliveries: []
            )
        }
    }

    public func fetchPullRequestDiff(owner: String, repo: String, index: Int) async throws -> [DiffFilePatch] {
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        let response = try await sendRaw(endpoint: "/repos/\(o)/\(r)/pulls/\(index).diff")
        let rawDiff = String(data: response.body, encoding: .utf8) ?? ""
        return UnifiedDiffParser.parse(rawDiff)
    }

    public func submitPullReview(
        owner: String,
        repo: String,
        index: Int,
        decision: PRReviewDecision,
        body: String,
        comments: [InlineReviewDraft]
    ) async throws {
        struct ReviewCommentPayload: Encodable {
            let path: String
            let body: String
            let newPosition: Int
            let oldPosition: Int
            enum CodingKeys: String, CodingKey {
                case path, body
                case newPosition = "new_position"
                case oldPosition = "old_position"
            }
        }
        struct ReviewPayload: Encodable {
            let body: String
            let event: String
            let comments: [ReviewCommentPayload]
        }
        let payload = ReviewPayload(
            body: body,
            event: decision.rawValue,
            comments: comments.map {
                ReviewCommentPayload(
                    path: $0.filePath, body: $0.body,
                    newPosition: $0.side == .new ? $0.lineNumber : 0,
                    oldPosition: $0.side == .old ? $0.lineNumber : 0
                )
            }
        )
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        _ = try await sendRaw(
            method: "POST",
            endpoint: "/repos/\(o)/\(r)/pulls/\(index)/reviews",
            body: try JSONEncoder().encode(payload)
        )
    }

    public func mergePullRequest(
        owner: String,
        repo: String,
        index: Int,
        strategy: PRMergeStrategy
    ) async throws {
        struct MergePayload: Encodable {
            let `Do`: String
        }
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        _ = try await sendRaw(
            method: "POST",
            endpoint: "/repos/\(o)/\(r)/pulls/\(index)/merge",
            body: try JSONEncoder().encode(MergePayload(Do: strategy.rawValue))
        )
    }

    // MARK: - Repo Ops (Secrets, Variables, Mirror, Webhooks)

    public func upsertActionSecret(owner: String, repo: String, name: String, value: String) async throws {
        struct SecretPayload: Encodable { let data: String }
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        let n = GiteaURLBuilder.encodedSegment(name)
        _ = try await sendRaw(
            method: "PUT",
            endpoint: "/repos/\(o)/\(r)/actions/secrets/\(n)",
            body: try JSONEncoder().encode(SecretPayload(data: value))
        )
    }

    public func triggerMirrorSync(owner: String, repo: String) async throws {
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        _ = try await sendRaw(method: "POST", endpoint: "/repos/\(o)/\(r)/mirror-sync")
    }

    public func replayWebhookTest(owner: String, repo: String, hookID: Int) async throws {
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        _ = try await sendRaw(method: "POST", endpoint: "/repos/\(o)/\(r)/hooks/\(hookID)/tests")
    }

    // MARK: - Actions, Job Logs (Range Fallback) & Runners

    public func fetchJobLogChunk(
        owner: String,
        repo: String,
        jobID: Int64,
        byteOffset: Int = 0
    ) async throws -> String {
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        let headers = byteOffset > 0 ? ["Range": "bytes=\(byteOffset)-"] : [:]
        let response = try await sendRaw(
            endpoint: "/repos/\(o)/\(r)/actions/jobs/\(jobID)/logs",
            additionalHeaders: headers
        )
        return String(data: response.body, encoding: .utf8) ?? ""
    }

    public func dispatchWorkflow(
        owner: String,
        repo: String,
        workflow: String,
        ref: String,
        inputs: [String: String]
    ) async throws {
        struct DispatchPayload: Encodable {
            let ref: String
            let inputs: [String: String]
        }
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        let w = GiteaURLBuilder.encodedSegment(workflow)
        _ = try await sendRaw(
            method: "POST",
            endpoint: "/repos/\(o)/\(r)/actions/workflows/\(w)/dispatches",
            body: try JSONEncoder().encode(DispatchPayload(ref: ref, inputs: inputs))
        )
    }

    public func createRunnerRegistrationToken() async throws -> String {
        struct TokenDTO: Decodable { let token: String }
        let dto: TokenDTO = try await fetchJSON(method: "POST", endpoint: "/admin/actions/runners/registration-token")
        return dto.token
    }

    // MARK: - Inbox & Admin Ops

    public func markNotificationThreadRead(threadID: String) async throws {
        let tid = GiteaURLBuilder.encodedSegment(threadID)
        _ = try await sendRaw(method: "PATCH", endpoint: "/notifications/threads/\(tid)")
    }

    public func triggerCronTask(name: String) async throws {
        let taskName = GiteaURLBuilder.encodedSegment(name)
        _ = try await sendRaw(method: "POST", endpoint: "/admin/cron/\(taskName)")
    }

    public func uploadReleaseAsset(
        owner: String,
        repo: String,
        releaseID: Int,
        fileName: String,
        data: Data
    ) async throws {
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        _ = try await sendRaw(
            method: "POST",
            endpoint: "/repos/\(o)/\(r)/releases/\(releaseID)/assets",
            queryItems: [URLQueryItem(name: "name", value: fileName)],
            body: data,
            additionalHeaders: ["Content-Type": "application/octet-stream"],
            timeout: 300
        )
    }

    // MARK: - Live Workspace Read Extensions

    public func fetchNotifications() async throws -> [NotificationThread] {
        struct RepoDTO: Decodable { let fullName: String? }
        struct SubjectDTO: Decodable { let title: String?; let type: String?; let url: String? }
        struct NotifyDTO: Decodable {
            let id: Int64; let unread: Bool?; let updatedAt: String?; let repository: RepoDTO?; let subject: SubjectDTO?
        }
        let dtos: [NotifyDTO] = try await fetchJSON(
            endpoint: "/notifications",
            queryItems: [URLQueryItem(name: "all", value: "true"), URLQueryItem(name: "limit", value: "30")]
        )
        return dtos.map { dto in
            let repoFull = dto.repository?.fullName ?? ""
            let type = dto.subject?.type ?? "Repository"
            let unread = dto.unread ?? false
            let category: NotificationCategory = !unread ? .archived : (type == "Pull" ? .mention : .pending)
            let prNumber = dto.subject?.url.flatMap { URL(string: $0)?.path.split(separator: "/").last }.flatMap { Int($0) }
            let deepLink: String
            if type == "Pull", let prNumber, repoFull.split(separator: "/").count == 2 {
                deepLink = "teapulse://pull/\(repoFull)/\(prNumber)"
            } else if repoFull.split(separator: "/").count == 2 {
                deepLink = "teapulse://repo/\(repoFull)"
            } else {
                deepLink = ""
            }
            return NotificationThread(
                id: "\(dto.id)", category: category, repoFullName: repoFull,
                subjectTitle: dto.subject?.title ?? "通知", subjectType: type,
                unread: unread, updatedAtText: String((dto.updatedAt ?? "").prefix(10)), deepLink: deepLink
            )
        }
    }

    public func fetchActionSecrets(owner: String, repo: String) async throws -> [RepoSecretItem] {
        struct SecretDTO: Decodable { let name: String; let createdAt: String? }
        let o = GiteaURLBuilder.encodedSegment(owner), r = GiteaURLBuilder.encodedSegment(repo)
        let dtos: [SecretDTO] = try await fetchJSON(endpoint: "/repos/\(o)/\(r)/actions/secrets")
        return dtos.map { RepoSecretItem(id: "sec-\($0.name)", name: $0.name, updatedAtText: String(($0.createdAt ?? "").prefix(10))) }
    }

    public func fetchActionVariables(owner: String, repo: String) async throws -> [RepoVariableItem] {
        struct VariableDTO: Decodable { let name: String; let data: String?; let value: String? }
        let o = GiteaURLBuilder.encodedSegment(owner), r = GiteaURLBuilder.encodedSegment(repo)
        let dtos: [VariableDTO] = try await fetchJSON(endpoint: "/repos/\(o)/\(r)/actions/variables")
        return dtos.map { RepoVariableItem(id: "var-\($0.name)", name: $0.name, value: $0.data ?? $0.value ?? "") }
    }

    public func fetchPullRequestComments(owner: String, repo: String, index: Int) async throws -> [PRTimelineComment] {
        struct UserRefDTO: Decodable { let login: String? }
        struct CommentDTO: Decodable { let id: Int; let body: String?; let createdAt: String?; let user: UserRefDTO? }
        let o = GiteaURLBuilder.encodedSegment(owner), r = GiteaURLBuilder.encodedSegment(repo)
        let dtos: [CommentDTO] = try await fetchJSON(endpoint: "/repos/\(o)/\(r)/issues/\(index)/comments")
        return dtos.compactMap { dto in
            let text = (dto.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return PRTimelineComment(
                id: "prc-\(dto.id)", author: dto.user?.login ?? "unknown",
                body: text, timestampText: String((dto.createdAt ?? "").prefix(10))
            )
        }
    }

    public func fetchCommitChecks(owner: String, repo: String, ref: String) async throws -> [CICheckItem] {
        struct StatusDTO: Decodable { let id: Int64?; let context: String?; let status: String? }
        struct CombinedDTO: Decodable { let statuses: [StatusDTO]? }
        let o = GiteaURLBuilder.encodedSegment(owner), r = GiteaURLBuilder.encodedSegment(repo)
        let refSeg = GiteaURLBuilder.encodedSegment(ref)
        let response = try await sendRaw(endpoint: "/repos/\(o)/\(r)/commits/\(refSeg)/status")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let items: [StatusDTO]
        if let combined = try? decoder.decode(CombinedDTO.self, from: response.body), let list = combined.statuses {
            items = list
        } else if let direct = try? decoder.decode([StatusDTO].self, from: response.body) {
            items = direct
        } else {
            return []
        }
        return items.enumerated().map { idx, item in
            let raw = (item.status ?? "pending").lowercased()
            let mapped: RunStatus = raw == "success" ? .success : ((raw == "failure" || raw == "error") ? .failure : .running)
            return CICheckItem(
                id: "chk-\(item.id ?? Int64(idx))-\(idx)",
                name: (item.context?.isEmpty == false ? item.context : nil) ?? "状态检查 #\(idx + 1)",
                status: mapped, durationText: raw, deepLink: "teapulse://repo/\(owner)/\(repo)"
            )
        }
    }

    public func fetchRepoWorkflowRuns(owner: String, repo: String, defaultBranch: String) async throws -> [WorkflowRun] {
        struct TaskDTO: Decodable {
            let id: Int64?; let name: String?; let displayTitle: String?; let headBranch: String?
            let headSha: String?; let status: String?; let runNumber: Int?; let workflowId: String?
        }
        struct TasksResponseDTO: Decodable { let workflowRuns: [TaskDTO]? }
        let o = GiteaURLBuilder.encodedSegment(owner), r = GiteaURLBuilder.encodedSegment(repo)
        let dto: TasksResponseDTO = try await fetchJSON(endpoint: "/repos/\(o)/\(r)/actions/tasks")
        return (dto.workflowRuns ?? []).enumerated().map { idx, task in
            let runID = task.id ?? Int64(idx + 1)
            let number = task.runNumber ?? Int(runID)
            let branch = (task.headBranch?.isEmpty == false ? task.headBranch : nil) ?? defaultBranch
            let sha = String((task.headSha ?? "HEAD").prefix(7))
            let title = task.displayTitle ?? task.name ?? task.workflowId ?? "Workflow #\(number)"
            let rawStatus = (task.status ?? "").lowercased()
            let status: RunStatus
            switch rawStatus {
            case "success", "completed": status = .success
            case "failure", "failed", "cancelled", "canceled": status = .failure
            case "waiting", "blocked": status = .waitingApproval
            default: status = .running
            }
            let summaryStep = WorkflowStepLog(
                id: "st-\(runID)-1", number: 1, name: "运行概览", status: status, durationSeconds: 0, isExpanded: true,
                lines: [ANSITerminalLine(id: "ln-\(runID)-1", lineNumber: 1, text: "状态：\(status.badgeLabel) · 分支 \(branch) · 提交 \(sha)", severity: status == .failure ? .error : .info)]
            )
            return WorkflowRun(
                id: "run-\(owner)-\(repo)-\(runID)", runNumber: number, jobID: runID,
                repoFullName: "\(owner)/\(repo)", workflowName: title,
                workflowFile: task.workflowId ?? "workflow.yml", branch: branch, commitSHA: sha,
                status: status, runnerName: "actions-runner", durationSeconds: 0, steps: [summaryStep]
            )
        }
    }

    public func fetchAdminCronTasks() async throws -> [CronTaskItem] {
        struct CronDTO: Decodable {
            let name: String; let schedule: String?; let next: String?; let prev: String?; let execTimes: Int?
        }
        let dtos: [CronDTO] = try await fetchJSON(endpoint: "/admin/cron")
        return dtos.map { dto in
            let lower = dto.name.lowercased()
            return CronTaskItem(
                id: "cron-\(dto.name)", name: dto.name, schedule: dto.schedule ?? "-",
                nextRunText: String((dto.next ?? "-").prefix(10)), lastRunText: String((dto.prev ?? "-").prefix(10)),
                execTimes: dto.execTimes ?? 0,
                isDestructive: lower.contains("delete") || lower.contains("cleanup") || lower.contains("purge")
            )
        }
    }

    public func fetchAdminUsers() async throws -> [AdminUserItem] {
        struct AdminUserDTO: Decodable {
            let id: Int; let login: String; let email: String?
            let isAdmin: Bool?; let restricted: Bool?; let prohibitLogin: Bool?
        }
        let dtos: [AdminUserDTO] = try await fetchJSON(endpoint: "/admin/users")
        return dtos.map {
            AdminUserItem(
                id: "usr-\($0.id)", login: $0.login, email: $0.email ?? "-",
                isAdmin: $0.isAdmin ?? false, isRestricted: $0.restricted ?? false,
                prohibitLogin: $0.prohibitLogin ?? false, repoCount: 0
            )
        }
    }
}
