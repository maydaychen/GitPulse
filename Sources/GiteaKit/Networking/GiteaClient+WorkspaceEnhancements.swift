import Foundation

extension GiteaClient {
    // MARK: - Starred Repositories

    public func fetchStarredRepositories(
        limit: Int = 50,
        currentUsername: String? = nil
    ) async throws -> [RepositorySummary] {
        let dtos: [RepoDTO] = try await fetchJSON(
            endpoint: "/user/starred",
            queryItems: [
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
        return dtos.map { dto in
            var summary = dto.toRepositorySummary(currentUsername: currentUsername)
            summary.isStarred = true
            return summary
        }
    }

    public func setRepositoryStarred(owner: String, repo: String, starred: Bool) async throws {
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        _ = try await sendRaw(
            method: starred ? "PUT" : "DELETE",
            endpoint: "/user/starred/\(o)/\(r)"
        )
    }

    // MARK: - Branches, Tags, Commits & Diff

    public func fetchRepoBranches(
        owner: String,
        repo: String,
        defaultBranch: String
    ) async throws -> [RepoBranchItem] {
        struct BranchCommitDTO: Decodable { let id: String?; let sha: String? }
        struct BranchDTO: Decodable { let name: String; let commit: BranchCommitDTO? }
        struct TagDTO: Decodable { let name: String; let id: String?; let commit: BranchCommitDTO? }

        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        async let branchesTask: [BranchDTO] = fetchJSON(
            endpoint: "/repos/\(o)/\(r)/branches",
            queryItems: [URLQueryItem(name: "limit", value: "50")]
        )
        async let tagsTask: [TagDTO]? = try? fetchJSON(
            endpoint: "/repos/\(o)/\(r)/tags",
            queryItems: [URLQueryItem(name: "limit", value: "20")]
        )

        let branchDTOs = try await branchesTask
        let tagDTOs = (await tagsTask) ?? []

        var items = branchDTOs.map { dto in
            let sha = dto.commit?.id ?? dto.commit?.sha ?? ""
            return RepoBranchItem(
                id: "branch-\(dto.name)",
                name: dto.name,
                commitSHA: String(sha.prefix(7)),
                isDefault: dto.name == defaultBranch,
                isTag: false
            )
        }
        items.sort { lhs, rhs in
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            return false
        }
        items.append(contentsOf: tagDTOs.map { dto in
            let sha = dto.commit?.sha ?? dto.commit?.id ?? dto.id ?? ""
            return RepoBranchItem(
                id: "tag-\(dto.name)",
                name: dto.name,
                commitSHA: String(sha.prefix(7)),
                isDefault: false,
                isTag: true
            )
        })
        return items
    }

    public func fetchRepoCommits(
        owner: String,
        repo: String,
        sha: String,
        limit: Int = 15
    ) async throws -> [RepoCommitItem] {
        struct CommitAuthorDTO: Decodable { let name: String?; let date: String? }
        struct CommitInnerDTO: Decodable { let message: String?; let author: CommitAuthorDTO? }
        struct UserLoginDTO: Decodable { let login: String? }
        struct CommitFileDTO: Decodable { let filename: String? }
        struct CommitDTO: Decodable {
            let sha: String
            let commit: CommitInnerDTO?
            let author: UserLoginDTO?
            let files: [CommitFileDTO]?
            let created: String?
        }

        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        let dtos: [CommitDTO] = try await fetchJSON(
            endpoint: "/repos/\(o)/\(r)/commits",
            queryItems: [
                URLQueryItem(name: "sha", value: sha),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
        return dtos.map { dto in
            let fullMessage = (dto.commit?.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let shortSHA = String(dto.sha.prefix(7))
            let title = fullMessage.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? shortSHA
            let authorName = (dto.author?.login?.isEmpty == false ? dto.author?.login : nil)
                ?? dto.commit?.author?.name
                ?? "unknown"
            let datePrefix = String((dto.commit?.author?.date ?? dto.created ?? "").prefix(10))
            return RepoCommitItem(
                id: dto.sha,
                sha: dto.sha,
                shortSHA: shortSHA,
                title: title,
                message: fullMessage,
                author: authorName,
                timestampText: datePrefix,
                filesChangedCount: dto.files?.count ?? 0
            )
        }
    }

    public func fetchCommitDiff(owner: String, repo: String, sha: String) async throws -> [DiffFilePatch] {
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        let s = GiteaURLBuilder.encodedSegment(sha)
        let response = try await sendRaw(endpoint: "/repos/\(o)/\(r)/git/commits/\(s).diff")
        let rawDiff = String(data: response.body, encoding: .utf8) ?? ""
        return UnifiedDiffParser.parse(rawDiff)
    }

    // MARK: - Actions Jobs, Secrets, Variables & Runners

    public func fetchActionJobStepsAndLogs(
        owner: String,
        repo: String,
        jobID: Int64,
        fallbackStatus: RunStatus
    ) async -> (runnerName: String?, durationSeconds: Int?, steps: [WorkflowStepLog]) {
        struct JobStepDTO: Decodable {
            let name: String?
            let status: String?
            let number: Int?
            let startedAt: String?
            let completedAt: String?
        }
        struct JobDetailDTO: Decodable {
            let runnerName: String?
            let startedAt: String?
            let completedAt: String?
            let steps: [JobStepDTO]?
        }

        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        async let jobTask: JobDetailDTO? = try? fetchJSON(endpoint: "/repos/\(o)/\(r)/actions/jobs/\(jobID)")
        async let logTask: String? = try? fetchJobLogChunk(owner: owner, repo: repo, jobID: jobID, byteOffset: 0)

        let job = await jobTask
        let rawLog = (await logTask ?? "").trimmingCharacters(in: .newlines)
        let duration = Self.durationBetween(job?.startedAt, job?.completedAt)

        if !rawLog.isEmpty {
            let parsedSteps = ANSITerminalParser.parseSteps(from: rawLog, runFailed: fallbackStatus == .failure)
            return (job?.runnerName, duration, parsedSteps)
        }

        let structuredSteps = (job?.steps ?? []).enumerated().map { idx, step in
            let stepNum = step.number ?? (idx + 1)
            let mapped = Self.mapActionStatus(step.status, fallback: fallbackStatus)
            let stepDuration = Self.durationBetween(step.startedAt, step.completedAt) ?? 0
            return WorkflowStepLog(
                id: "job-\(jobID)-step-\(stepNum)",
                number: stepNum,
                name: (step.name?.isEmpty == false ? step.name : nil) ?? "步骤 #\(stepNum)",
                status: mapped,
                durationSeconds: stepDuration,
                isExpanded: mapped == .failure,
                firstErrorLineIndex: nil,
                lines: []
            )
        }
        return (job?.runnerName, duration, structuredSteps)
    }

    public func deleteActionSecret(owner: String, repo: String, name: String) async throws {
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        let n = GiteaURLBuilder.encodedSegment(name)
        _ = try await sendRaw(method: "DELETE", endpoint: "/repos/\(o)/\(r)/actions/secrets/\(n)")
    }

    public func upsertActionVariable(
        owner: String,
        repo: String,
        name: String,
        value: String,
        exists: Bool
    ) async throws {
        struct VariablePayload: Encodable { let value: String }
        let endpoint = actionVariableEndpoint(owner: owner, repo: repo, name: name)
        let encoded = try JSONEncoder().encode(VariablePayload(value: value))

        if exists {
            do {
                _ = try await sendRaw(method: "PUT", endpoint: endpoint, body: encoded)
            } catch GiteaClientError.httpStatus(404, _) {
                _ = try await sendRaw(method: "POST", endpoint: endpoint, body: encoded)
            }
        } else {
            do {
                _ = try await sendRaw(method: "POST", endpoint: endpoint, body: encoded)
            } catch GiteaClientError.httpStatus(let code, _) where code == 400 || code == 409 {
                _ = try await sendRaw(method: "PUT", endpoint: endpoint, body: encoded)
            }
        }
    }

    public func deleteActionVariable(owner: String, repo: String, name: String) async throws {
        _ = try await sendRaw(
            method: "DELETE",
            endpoint: actionVariableEndpoint(owner: owner, repo: repo, name: name)
        )
    }

    private func actionVariableEndpoint(owner: String, repo: String, name: String) -> String {
        let o = GiteaURLBuilder.encodedSegment(owner)
        let r = GiteaURLBuilder.encodedSegment(repo)
        let n = GiteaURLBuilder.encodedSegment(name)
        return "/repos/\(o)/\(r)/actions/variables/\(n)"
    }

    public func fetchAvailableRunners(
        organizations: [OrganizationSummary],
        repositories: [RepositorySummary]
    ) async -> [RunnerNode] {
        var endpoints = ["/admin/actions/runners", "/user/actions/runners"]
        endpoints.append(contentsOf: organizations.prefix(3).map {
            "/orgs/\(GiteaURLBuilder.encodedSegment($0.username))/actions/runners"
        })
        var collected: [RunnerNode] = []
        var seenIDs = Set<String>()

        for endpoint in endpoints {
            let batch = (try? await fetchRunners(endpoint: endpoint)) ?? []
            for runner in batch where seenIDs.insert(runner.id).inserted {
                collected.append(runner)
            }
        }
        if collected.isEmpty {
            for repo in repositories.filter({ !$0.isMirror }).prefix(2) {
                let o = GiteaURLBuilder.encodedSegment(repo.owner)
                let r = GiteaURLBuilder.encodedSegment(repo.name)
                let batch = (try? await fetchRunners(endpoint: "/repos/\(o)/\(r)/actions/runners")) ?? []
                for runner in batch where seenIDs.insert(runner.id).inserted {
                    collected.append(runner)
                }
            }
        }
        return collected
    }

    private func fetchRunners(endpoint: String) async throws -> [RunnerNode] {
        struct LabelDTO: Decodable {
            let value: String
            init(from decoder: Decoder) throws {
                if let single = try? decoder.singleValueContainer(),
                   let text = try? single.decode(String.self) {
                    value = text
                    return
                }
                enum CodingKeys: String, CodingKey { case name }
                let container = try decoder.container(keyedBy: CodingKeys.self)
                value = (try? container.decode(String.self, forKey: .name)) ?? ""
            }
        }
        struct RunnerDTO: Decodable {
            let id: Int64
            let name: String?
            let status: String?
            let busy: Bool?
            let ephemeral: Bool?
            let version: String?
            let labels: [LabelDTO]?
        }
        struct RunnersWrapperDTO: Decodable { let runners: [RunnerDTO]? }

        let response = try await sendRaw(endpoint: endpoint)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let dtos: [RunnerDTO]
        if let wrapped = try? decoder.decode(RunnersWrapperDTO.self, from: response.body), let list = wrapped.runners {
            dtos = list
        } else if let direct = try? decoder.decode([RunnerDTO].self, from: response.body) {
            dtos = direct
        } else {
            return []
        }
        return dtos.map { dto in
            let raw = (dto.status ?? "").lowercased()
            let onlineStatus: RunnerOnlineStatus
            if dto.busy == true || raw.contains("busy") || raw.contains("active") {
                onlineStatus = .busy
            } else if raw.contains("offline") || raw == "0" {
                onlineStatus = .offline
            } else {
                onlineStatus = .online
            }
            let labels = (dto.labels ?? []).map(\.value).filter { !$0.isEmpty }
            return RunnerNode(
                id: "runner-\(dto.id)",
                name: (dto.name?.isEmpty == false ? dto.name : nil) ?? "runner-\(dto.id)",
                hostLabel: dto.ephemeral == true ? "ephemeral" : "self-hosted",
                status: onlineStatus,
                labels: labels,
                activeJobTitle: onlineStatus == .busy ? "执行中" : nil,
                version: dto.version ?? "-"
            )
        }
    }

    private static func mapActionStatus(_ raw: String?, fallback: RunStatus) -> RunStatus {
        switch (raw ?? "").lowercased() {
        case "success", "completed": return .success
        case "failure", "failed", "cancelled", "canceled": return .failure
        case "waiting", "blocked": return .waitingApproval
        case "running", "in_progress": return .running
        default: return fallback
        }
    }

    private static func durationBetween(_ startRaw: String?, _ endRaw: String?) -> Int? {
        guard let startRaw, let endRaw,
              let start = parseISO8601(startRaw), let end = parseISO8601(endRaw) else { return nil }
        return max(0, Int(end.timeIntervalSince(start)))
    }

    private static func parseISO8601(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return standard.date(from: value)
    }
}
