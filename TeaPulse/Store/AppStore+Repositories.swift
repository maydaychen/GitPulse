import Foundation
import GiteaKit

extension AppStore {
    public func repository(named fullName: String) -> RepositorySummary? {
        repositories.first { $0.fullName.caseInsensitiveCompare(fullName) == .orderedSame }
    }

    public func canonicalRepoName(_ fullName: String) -> String {
        repository(named: fullName)?.fullName ?? fullName
    }

    /// Merge declared user organizations with organization owners present in loaded repositories.
    public var availableOrganizations: [OrganizationSummary] {
        var totalCounts: [String: Int] = [:]
        var mergedByKey: [String: OrganizationSummary] = [:]

        for org in organizations {
            let slug = org.username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !slug.isEmpty else { continue }
            let key = slug.lowercased()
            if mergedByKey[key] == nil {
                mergedByKey[key] = OrganizationSummary(id: org.id, username: slug, fullName: org.fullName)
            }
        }

        for repo in repositories where isOrganizationRepository(repo) {
            let owner = repo.owner.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !owner.isEmpty else { continue }
            let key = owner.lowercased()
            totalCounts[key, default: 0] += 1
            if mergedByKey[key] == nil {
                mergedByKey[key] = OrganizationSummary(id: "org-\(key)", username: owner)
            }
        }

        return mergedByKey.values.sorted { lhs, rhs in
            let lhsCount = totalCounts[lhs.username.lowercased(), default: 0]
            let rhsCount = totalCounts[rhs.username.lowercased(), default: 0]
            if lhsCount != rhsCount {
                return lhsCount > rhsCount
            }
            return lhs.username.localizedCaseInsensitiveCompare(rhs.username) == .orderedAscending
        }
    }

    public var allOrganizationsRepoCount: Int {
        repositories.count { matchesOrganizationCount($0) }
    }

    public func repositoryCount(forOrganization orgUsername: String) -> Int {
        repositories.count { repo in
            matchesOrganizationCount(repo)
                && repo.owner.caseInsensitiveCompare(orgUsername) == .orderedSame
        }
    }

    public func isOrganizationSelected(_ orgUsername: String) -> Bool {
        selectedOrganizationFilter?.caseInsensitiveCompare(orgUsername) == .orderedSame
    }

    public func selectRepoScope(_ scope: RepoScope) {
        repoScopeFilter = scope
        if scope == .all || scope == .personal {
            selectedOrganizationFilter = nil
        }
    }

    public func clearOrganizationFilter() {
        if repoScopeFilter == .all {
            repoScopeFilter = .org
        }
        selectedOrganizationFilter = nil
    }

    public func toggleOrganizationFilter(_ orgUsername: String) {
        if isOrganizationSelected(orgUsername) {
            selectedOrganizationFilter = nil
        } else {
            selectedOrganizationFilter = orgUsername
            if repoScopeFilter == .all || repoScopeFilter == .personal {
                repoScopeFilter = .org
            }
        }
    }

    public var filteredRepositories: [RepositorySummary] {
        let query = repoSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let selectedOrg = selectedOrganizationFilter?.trimmingCharacters(in: .whitespacesAndNewlines)
        let orgLookup = Dictionary(
            availableOrganizations.map { ($0.username.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return repositories.filter { repo in
            let isOrgRepo = isOrganizationRepository(repo)
            let matchesScope: Bool
            switch repoScopeFilter {
            case .all:
                matchesScope = true
            case .personal:
                matchesScope = repo.scope == .personal && !repo.isOrganizationOwned
            case .org:
                matchesScope = isOrgRepo
            case .mirror:
                matchesScope = repo.isMirror
            case .starred:
                matchesScope = repo.isStarred
            }

            let matchesOrg: Bool
            if let selectedOrg, !selectedOrg.isEmpty {
                matchesOrg = isOrgRepo && repo.owner.caseInsensitiveCompare(selectedOrg) == .orderedSame
            } else {
                matchesOrg = true
            }

            let matchesQuery: Bool
            if query.isEmpty {
                matchesQuery = true
            } else if repo.fullName.lowercased().contains(query) {
                matchesQuery = true
            } else if isOrgRepo, let orgInfo = orgLookup[repo.owner.lowercased()] {
                matchesQuery = orgInfo.username.lowercased().contains(query)
                    || orgInfo.fullName.lowercased().contains(query)
            } else {
                matchesQuery = false
            }

            return matchesScope && matchesOrg && matchesQuery
        }
    }

    internal func isOrganizationRepository(_ repo: RepositorySummary) -> Bool {
        repo.scope == .org || repo.isOrganizationOwned
    }

    private func matchesOrganizationCount(_ repo: RepositorySummary) -> Bool {
        guard isOrganizationRepository(repo) else { return false }
        switch repoScopeFilter {
        case .mirror:
            return repo.isMirror
        case .starred:
            return repo.isStarred
        case .all, .personal, .org:
            return true
        }
    }

    internal static func preferredReadmeEntry(in files: [RepoFileEntry]) -> RepoFileEntry? {
        let regular = files.filter { !$0.isDirectory }
        if let exact = regular.first(where: { $0.name.lowercased() == "readme.md" }) { return exact }
        if let prefix = regular.first(where: { $0.name.lowercased().hasPrefix("readme") }) { return prefix }
        if let wikiHome = regular.first(where: { ["home.md", "index.md"].contains($0.name.lowercased()) }) { return wikiHome }
        return regular.first(where: { $0.name.lowercased().hasSuffix(".md") })
    }

    internal static func buildReadmeText(
        repo: RepositorySummary, readmeEntry: RepoFileEntry?, readmeText: String?,
        files: [RepoFileEntry], contentError: Error?
    ) -> String {
        if let readmeEntry, let readmeText {
            return readmeText.isEmpty ? "（\(readmeEntry.name) 内容为空）" : readmeText
        }
        if let contentError {
            if case .httpStatus(404, _) = contentError as? GiteaClientError {
                return "该仓库暂无 README 或文件"
            }
            return "无法加载仓库详情：\(contentError.localizedDescription)"
        }
        guard !files.isEmpty else { return "该仓库暂无 README 或文件" }
        let listing = files.prefix(20).map { "- \($0.isDirectory ? "[目录] " : "")\($0.path)" }.joined(separator: "\n")
        return "# \(repo.name)\n\n未检测到 README，根目录包含 \(files.count) 项：\n\n\(listing)"
    }

    public func loadRepositoryFileContent(repoFullName: String, filePath: String) async {
        guard !isDemoMode, let client = makeActiveClient(),
              let repo = repository(named: repoFullName) else { return }
        let canonicalName = repo.fullName
        let activeRef = activeBranch(for: repo)
        let sessionID = profile.id
        do {
            let text = try await client.fetchRepoFileContent(
                owner: repo.owner, repo: repo.name, path: filePath, ref: activeRef
            )
            guard !isDemoMode, profile.id == sessionID,
                  var entries = repoFiles[canonicalName],
                  let idx = entries.firstIndex(where: { $0.path == filePath }) else { return }
            entries[idx].content = text
            repoFiles[canonicalName] = entries
        } catch {
            guard !isDemoMode, profile.id == sessionID else { return }
            showToast(error.localizedDescription)
        }
    }
}
