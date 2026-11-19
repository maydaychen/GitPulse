import Foundation
import GiteaKit

extension AppStore {
    public static let autoRefreshCooldownSeconds: TimeInterval = 60
    public static let repoTabCacheTTLSeconds: TimeInterval = 60
    public static let maxCachedCommitDiffs = 24
    public static let maxCachedFileContents = 20
    public static let maxCachedRunLogs = 16

    // MARK: - Foreground Cooldown

    @discardableResult
    public func refreshLiveInstanceDataIfStale(
        now: Date = Date(),
        cooldown: TimeInterval = AppStore.autoRefreshCooldownSeconds
    ) async -> Bool {
        if isDemoMode {
            if let last = lastWorkspaceRefreshAt, now.timeIntervalSince(last) < cooldown {
                return false
            }
            await refreshEndpointProbe()
            lastWorkspaceRefreshAt = now
            return true
        }
        if !hasLoadedLiveWorkspace {
            await refreshLiveInstanceData()
            return hasLoadedLiveWorkspace
        }
        if let last = lastWorkspaceRefreshAt, now.timeIntervalSince(last) < cooldown {
            return false
        }
        await refreshLiveInstanceData()
        return true
    }

    // MARK: - Nonisolated Bounded-Concurrency Fetching

    nonisolated static func enrichPullRequestConcurrent(
        _ pr: PullRequestDetail, owner: String, repo: String, client: GiteaClient
    ) async -> PullRequestDetail {
        var updated = pr
        let checkRef = (pr.headSHA?.isEmpty == false ? pr.headSHA : nil) ?? pr.headBranch
        async let patchesTask = client.fetchPullRequestDiff(owner: owner, repo: repo, index: pr.number)
        async let commentsTask = client.fetchPullRequestComments(owner: owner, repo: repo, index: pr.number)
        async let checksTask = client.fetchCommitChecks(owner: owner, repo: repo, ref: checkRef)
        if let patches = try? await patchesTask, !patches.isEmpty { updated.files = patches }
        if let comments = try? await commentsTask, !comments.isEmpty { updated.comments = comments }
        if let checks = try? await checksTask, !checks.isEmpty { updated.checks = checks }
        return updated
    }

    nonisolated static func enrichFirstPRs(
        _ fetched: [PullRequestDetail]?,
        owner: String,
        repo: String,
        client: GiteaClient,
        limit: Int = 8
    ) async -> [PullRequestDetail]? {
        guard var prs = fetched else { return nil }
        let slice = Array(prs.prefix(limit))
        let enriched = await boundedConcurrentMap(slice, maxConcurrency: 6) { pr in
            await enrichPullRequestConcurrent(pr, owner: owner, repo: repo, client: client)
        }
        for (idx, item) in enriched.enumerated() {
            prs[idx] = item
        }
        return prs
    }

    nonisolated static func fetchOpenPRsAndEnrich(
        targets: [RepositorySummary],
        client: GiteaClient
    ) async -> [PullRequestDetail] {
        let batches = await boundedConcurrentMap(targets, maxConcurrency: 6) { repo in
            (try? await client.fetchPullRequests(owner: repo.owner, repo: repo.name)) ?? []
        }
        var prs = batches.flatMap { $0 }
        let enriched = await boundedConcurrentMap(Array(prs.prefix(8)), maxConcurrency: 6) { pr in
            let parts = pr.repoFullName.split(separator: "/").map(String.init)
            guard parts.count == 2 else { return pr }
            return await enrichPullRequestConcurrent(pr, owner: parts[0], repo: parts[1], client: client)
        }
        for (idx, item) in enriched.enumerated() {
            prs[idx] = item
        }
        return prs
    }

    nonisolated static func fetchRecentWorkflowRuns(
        repos: [RepositorySummary],
        client: GiteaClient
    ) async -> [WorkflowRun] {
        let batches = await boundedConcurrentMap(Array(repos.prefix(6)), maxConcurrency: 6) { repo in
            (try? await client.fetchRepoWorkflowRuns(
                owner: repo.owner, repo: repo.name, defaultBranch: repo.defaultBranch
            )) ?? []
        }
        return batches.flatMap { $0 }
    }

    nonisolated static func fetchOrganizationFallbackActivities(
        orgs: [String],
        client: GiteaClient
    ) async -> [ActivityEvent] {
        let batches = await boundedConcurrentMap(Array(orgs.prefix(3)), maxConcurrency: 3) { org in
            (try? await client.fetchOrgActivityFeeds(org: org, limit: 10)) ?? []
        }
        return Array(batches.flatMap { $0 }.prefix(20))
    }

    // MARK: - Tab-Scoped Repository Lazy Loading

    public func loadRepositoryTabIfNeeded(
        repoFullName: String,
        tab: RepoWorkspaceTab,
        directoryPath: String = "",
        force: Bool = false,
        now: Date = Date()
    ) async {
        guard !isDemoMode, let client = makeActiveClient(),
              let repo = repository(named: repoFullName) else { return }
        let canonicalName = repo.fullName
        let repoKey = canonicalName.lowercased()
        let activeRef = activeBranch(for: repo)
        let cacheKey = Self.repoTabCacheKey(repoKey: repoKey, branch: activeRef, directoryPath: directoryPath, tab: tab)
        if !force, let cachedAt = loadedRepoTabTimestamps[cacheKey],
           now.timeIntervalSince(cachedAt) < Self.repoTabCacheTTLSeconds {
            return
        }

        let sessionID = profile.id
        loadingRepoNames.insert(repoKey)
        defer {
            loadingRepoNames.remove(repoKey)
            if !isDemoMode, profile.id == sessionID { loadedRepoNames.insert(repoKey) }
        }

        switch tab {
        case .readme, .files:
            await loadRepoContentAndOverviewTab(
                repo: repo, canonicalName: canonicalName, repoKey: repoKey,
                activeRef: activeRef, directoryPath: directoryPath,
                client: client, sessionID: sessionID, now: now
            )
        case .pullRequests:
            let fetched = try? await client.fetchPullRequests(owner: repo.owner, repo: repo.name)
            let enriched = await Self.enrichFirstPRs(fetched, owner: repo.owner, repo: repo.name, client: client)
            guard !isDemoMode, profile.id == sessionID else { return }
            if let enriched {
                loadedPRIDs.formUnion(enriched.map(\.id))
                pullRequests.removeAll { $0.repoFullName.caseInsensitiveCompare(canonicalName) == .orderedSame }
                pullRequests.append(contentsOf: enriched)
            }
            loadedRepoTabTimestamps[cacheKey] = now
        case .issues:
            let issues = try? await client.fetchIssues(owner: repo.owner, repo: repo.name)
            guard !isDemoMode, profile.id == sessionID else { return }
            if let issues { issuesByRepo[canonicalName] = issues }
            loadedRepoTabTimestamps[cacheKey] = now
        case .ops:
            async let hooksTask = client.fetchWebhooks(owner: repo.owner, repo: repo.name)
            async let secretsTask = client.fetchActionSecrets(owner: repo.owner, repo: repo.name)
            async let varsTask = client.fetchActionVariables(owner: repo.owner, repo: repo.name)
            async let releasesTask = client.fetchReleases(owner: repo.owner, repo: repo.name)
            async let runsTask = client.fetchRepoWorkflowRuns(owner: repo.owner, repo: repo.name, defaultBranch: repo.defaultBranch)
            let hooks = try? await hooksTask
            let secrets = try? await secretsTask
            let variables = try? await varsTask
            let releases = try? await releasesTask
            let repoRuns = try? await runsTask
            guard !isDemoMode, profile.id == sessionID else { return }
            if let hooks { webhooksByRepo[canonicalName] = hooks }
            if let secrets { secretsByRepo[canonicalName] = secrets }
            if let variables { variablesByRepo[canonicalName] = variables }
            if let releases { releasesByRepo[canonicalName] = releases }
            if let repoRuns, !repoRuns.isEmpty {
                runs.removeAll { $0.repoFullName.caseInsensitiveCompare(canonicalName) == .orderedSame }
                runs.insert(contentsOf: repoRuns, at: 0)
                rebuildPinnedRepos()
            }
            loadedRepoTabTimestamps[cacheKey] = now
        }
    }

    private func loadRepoContentAndOverviewTab(
        repo: RepositorySummary,
        canonicalName: String,
        repoKey: String,
        activeRef: String,
        directoryPath: String,
        client: GiteaClient,
        sessionID: String,
        now: Date
    ) async {
        async let branchesTask: [RepoBranchItem]? = directoryPath.isEmpty
            ? (try? await client.fetchRepoBranches(owner: repo.owner, repo: repo.name, defaultBranch: repo.defaultBranch))
            : nil
        async let commitsTask: [RepoCommitItem]? = directoryPath.isEmpty
            ? (try? await client.fetchRepoCommits(owner: repo.owner, repo: repo.name, sha: activeRef))
            : nil

        var resolvedFiles: [RepoFileEntry]
        var contentError: Error?
        do {
            resolvedFiles = try await client.fetchRepoContents(
                owner: repo.owner, repo: repo.name, path: directoryPath, ref: activeRef
            )
        } catch {
            resolvedFiles = []
            contentError = error
        }

        let branches = await branchesTask
        let commits = await commitsTask
        guard !isDemoMode, profile.id == sessionID else { return }

        if directoryPath.isEmpty {
            let readmeTarget = Self.preferredReadmeEntry(in: resolvedFiles)
            var loadedReadmeText: String?
            if let entry = readmeTarget {
                loadedReadmeText = try? await client.fetchRepoFileContent(
                    owner: repo.owner, repo: repo.name, path: entry.path, ref: activeRef
                )
                if let loadedReadmeText, let matchIdx = resolvedFiles.firstIndex(where: { $0.path == entry.path }) {
                    resolvedFiles[matchIdx].content = loadedReadmeText
                }
            }
            guard !isDemoMode, profile.id == sessionID else { return }
            if let branches { branchesByRepo[canonicalName] = branches }
            if let commits { commitsByRepo[canonicalName] = commits }
            if let repoIdx = repositories.firstIndex(where: { $0.id == repo.id }) {
                repositories[repoIdx].readmeMarkdown = Self.buildReadmeText(
                    repo: repo, readmeEntry: readmeTarget, readmeText: loadedReadmeText,
                    files: resolvedFiles, contentError: contentError
                )
            }
            loadedRepoTabTimestamps[Self.repoTabCacheKey(repoKey: repoKey, branch: activeRef, directoryPath: "", tab: .readme)] = now
            loadedRepoTabTimestamps[Self.repoTabCacheKey(repoKey: repoKey, branch: activeRef, directoryPath: "", tab: .files)] = now
        } else {
            loadedRepoTabTimestamps[Self.repoTabCacheKey(repoKey: repoKey, branch: activeRef, directoryPath: directoryPath, tab: .files)] = now
        }

        if let contentError {
            if case .httpStatus(404, _) = contentError as? GiteaClientError {} else {
                showToast(contentError.localizedDescription)
            }
        }
        repoFiles[canonicalName] = resolvedFiles
    }

    internal func markAllRepoTabsLoaded(repoFullName: String, branch: String, now: Date = Date()) {
        let repoKey = repoFullName.lowercased()
        for tab in RepoWorkspaceTab.allCases {
            loadedRepoTabTimestamps[Self.repoTabCacheKey(repoKey: repoKey, branch: branch, directoryPath: "", tab: tab)] = now
        }
    }

    internal func invalidateRepoTabCache(repoFullName: String) {
        let prefix = "\(repoFullName.lowercased())::"
        loadedRepoTabTimestamps = loadedRepoTabTimestamps.filter { !$0.key.hasPrefix(prefix) }
    }

    private static func repoTabCacheKey(repoKey: String, branch: String, directoryPath: String, tab: RepoWorkspaceTab) -> String {
        "\(repoKey)::\(branch)::\(directoryPath)::\(tab.rawValue)"
    }

    // MARK: - Bounded Cache Eviction

    internal func cacheCommitDiff(_ patches: [DiffFilePatch], forKey key: String) {
        commitDiffsBySHA[key] = patches
        commitDiffOrder.removeAll { $0 == key }
        commitDiffOrder.append(key)
        while commitDiffOrder.count > Self.maxCachedCommitDiffs {
            let evicted = commitDiffOrder.removeFirst()
            commitDiffsBySHA.removeValue(forKey: evicted)
        }
    }

    internal func recordCachedFileContent(repoFullName: String, filePath: String) {
        if filePath.lowercased().hasPrefix("readme") { return }
        let entryKey = "\(repoFullName)::\(filePath)"
        loadedFileContentOrder.removeAll { $0 == entryKey }
        loadedFileContentOrder.append(entryKey)
        while loadedFileContentOrder.count > Self.maxCachedFileContents {
            let evicted = loadedFileContentOrder.removeFirst()
            let parts = evicted.components(separatedBy: "::")
            guard parts.count == 2 else { continue }
            if var entries = repoFiles[parts[0]],
               let idx = entries.firstIndex(where: { $0.path == parts[1] }) {
                entries[idx].content = nil
                repoFiles[parts[0]] = entries
            }
        }
    }

    internal func recordCachedRunLogs(runID: String) {
        loadedRunLogOrder.removeAll { $0 == runID }
        loadedRunLogOrder.append(runID)
        while loadedRunLogOrder.count > Self.maxCachedRunLogs {
            let evicted = loadedRunLogOrder.removeFirst()
            loadedRunIDs.remove(evicted)
            if let idx = runs.firstIndex(where: { $0.id == evicted }) {
                runs[idx].steps = []
            }
        }
    }
}
