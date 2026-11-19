import Foundation
import GiteaKit
#if canImport(WidgetKit)
import WidgetKit
#endif

extension AppStore {
    private struct PinnedSelection: Codable {
        var isCustomized: Bool
        var repoNames: [String]
    }

    private var pinnedStorageKey: String {
        "teapulse.pinned.repos.\(profile.id)"
    }

    // MARK: - Pinned Repositories & Stars

    public func isRepositoryPinned(_ repoFullName: String) -> Bool {
        pinnedRepos.contains { $0.fullName.caseInsensitiveCompare(repoFullName) == .orderedSame }
    }

    public func togglePinRepository(_ repoFullName: String) {
        let canonical = canonicalRepoName(repoFullName)
        var selection = loadPinnedSelection()
        if !selection.isCustomized {
            selection = PinnedSelection(
                isCustomized: true,
                repoNames: pinnedRepos.map { canonicalRepoName($0.fullName) }
            )
        }
        let wasPinned: Bool
        if let idx = selection.repoNames.firstIndex(where: { $0.caseInsensitiveCompare(canonical) == .orderedSame }) {
            selection.repoNames.remove(at: idx)
            wasPinned = true
        } else {
            selection.repoNames.append(canonical)
            wasPinned = false
        }
        savePinnedSelection(selection)
        rebuildPinnedRepos()
        showToast(wasPinned ? "已取消置顶 \(canonical)" : "已置顶 \(canonical)")
    }

    public func rebuildPinnedRepos() {
        let selection = loadPinnedSelection()
        if !selection.isCustomized {
            if isDemoMode { return }
            pinnedRepos = repositories.prefix(4).map { makePinnedSummary(for: $0) }
            return
        }
        pinnedRepos = selection.repoNames.compactMap { name in
            guard let repo = repository(named: name) else { return nil }
            return makePinnedSummary(for: repo)
        }
    }

    private func makePinnedSummary(for repo: RepositorySummary) -> PinnedRepoSummary {
        PinnedRepoSummary(
            id: "pin-\(repo.id)",
            fullName: repo.fullName,
            defaultBranch: repo.defaultBranch,
            openPRCount: repo.openPRCount,
            ciStatus: latestCIStatus(for: repo.fullName),
            isMirror: repo.isMirror
        )
    }

    private func latestCIStatus(for repoFullName: String) -> RunStatus {
        runs.first { $0.repoFullName.caseInsensitiveCompare(repoFullName) == .orderedSame }?.status ?? .success
    }

    private func loadPinnedSelection() -> PinnedSelection {
        guard let data = defaults.data(forKey: pinnedStorageKey),
              let decoded = try? JSONDecoder().decode(PinnedSelection.self, from: data) else {
            return PinnedSelection(isCustomized: false, repoNames: [])
        }
        return decoded
    }

    private func savePinnedSelection(_ selection: PinnedSelection) {
        guard let data = try? JSONEncoder().encode(selection) else { return }
        defaults.set(data, forKey: pinnedStorageKey)
    }

    @discardableResult
    public func toggleStarRepository(repoID: String) async -> Bool {
        guard let idx = repositories.firstIndex(where: { $0.id == repoID }) else { return false }
        let targetStarred = !repositories[idx].isStarred
        let repoFullName = repositories[idx].fullName
        guard await performRepoOperation(repoFullName, operation: { client, owner, repo in
            try await client.setRepositoryStarred(owner: owner, repo: repo, starred: targetStarred)
        }) else { return false }
        guard let updatedIdx = repositories.firstIndex(where: { $0.id == repoID }) else { return false }
        repositories[updatedIdx].isStarred = targetStarred
        repositories[updatedIdx].stars = max(0, repositories[updatedIdx].stars + (targetStarred ? 1 : -1))
        rebuildPinnedRepos()
        showToast(targetStarred ? "已收藏 \(repositories[updatedIdx].name)" : "已取消收藏 \(repositories[updatedIdx].name)")
        return true
    }

    // MARK: - Branches, Commits & Diff

    public func activeBranch(for repo: RepositorySummary) -> String {
        let key = repo.fullName.lowercased()
        if let selected = selectedBranchByRepo[key], !selected.isEmpty {
            return selected
        }
        return repo.defaultBranch
    }

    public func selectRepositoryBranch(repoFullName: String, branch: String) async {
        let canonical = canonicalRepoName(repoFullName)
        selectedBranchByRepo[canonical.lowercased()] = branch
        invalidateRepoTabCache(repoFullName: canonical)
        guard !isDemoMode else {
            showToast("已切换至 \(branch)")
            return
        }
        await loadRepositoryDetails(repoFullName: canonical, directoryPath: "")
    }

    public func loadCommitDiff(repoFullName: String, sha: String) async -> [DiffFilePatch] {
        let cacheKey = "\(canonicalRepoName(repoFullName).lowercased())::\(sha.lowercased())"
        if let cached = commitDiffsBySHA[cacheKey] {
            commitDiffOrder.removeAll { $0 == cacheKey }
            commitDiffOrder.append(cacheKey)
            return cached
        }
        if let demoBySHA = commitDiffsBySHA[sha] { return demoBySHA }
        guard !isDemoMode, let client = makeActiveClient() else { return [] }
        let parts = canonicalRepoName(repoFullName).split(separator: "/").map(String.init)
        guard parts.count == 2 else { return [] }
        let sessionID = profile.id
        do {
            let patches = try await client.fetchCommitDiff(owner: parts[0], repo: parts[1], sha: sha)
            guard !isDemoMode, profile.id == sessionID else { return patches }
            cacheCommitDiff(patches, forKey: cacheKey)
            return patches
        } catch {
            guard !isDemoMode, profile.id == sessionID else { return [] }
            showToast(error.localizedDescription)
            return []
        }
    }

    // MARK: - Pull Requests & Workflow Logs

    public func reloadPullRequestDetails(_ pr: PullRequestDetail) async {
        loadedPRIDs.remove(pr.id)
        await loadPullRequestDetails(pr)
    }

    public func loadPullRequestDetails(_ pr: PullRequestDetail) async {
        guard !isDemoMode, !loadedPRIDs.contains(pr.id), !loadingPRIDs.contains(pr.id),
              let client = makeActiveClient() else { return }
        let parts = canonicalRepoName(pr.repoFullName).split(separator: "/").map(String.init)
        guard parts.count == 2 else { return }
        let sessionID = profile.id
        loadingPRIDs.insert(pr.id)
        defer {
            loadingPRIDs.remove(pr.id)
            if !isDemoMode, profile.id == sessionID { loadedPRIDs.insert(pr.id) }
        }
        let enriched = await enrichPullRequest(pr, owner: parts[0], repo: parts[1], client: client)
        guard !isDemoMode, profile.id == sessionID,
              let idx = pullRequests.firstIndex(where: { $0.id == pr.id }) else { return }
        pullRequests[idx] = enriched
    }

    internal func enrichPullRequest(
        _ pr: PullRequestDetail, owner: String, repo: String, client: GiteaClient
    ) async -> PullRequestDetail {
        await Self.enrichPullRequestConcurrent(pr, owner: owner, repo: repo, client: client)
    }

    public func isLoadingRunLogs(_ run: WorkflowRun) -> Bool {
        guard !isDemoMode else { return false }
        return loadingRunIDs.contains(run.id)
    }

    public func loadWorkflowRunLogs(for run: WorkflowRun, force: Bool = false) async {
        guard !isDemoMode, let client = makeActiveClient() else { return }
        if !force, loadedRunIDs.contains(run.id) { return }
        guard !loadingRunIDs.contains(run.id) else { return }
        let parts = canonicalRepoName(run.repoFullName).split(separator: "/").map(String.init)
        guard parts.count == 2 else { return }

        let sessionID = profile.id
        loadingRunIDs.insert(run.id)
        defer {
            loadingRunIDs.remove(run.id)
            if !isDemoMode, profile.id == sessionID { loadedRunIDs.insert(run.id) }
        }

        let fetched = await client.fetchActionJobStepsAndLogs(
            owner: parts[0], repo: parts[1], jobID: run.jobID, fallbackStatus: run.status
        )
        guard !isDemoMode, profile.id == sessionID,
              let idx = runs.firstIndex(where: { $0.id == run.id }) else { return }
        if let runner = fetched.runnerName, !runner.isEmpty {
            runs[idx].runnerName = runner
        }
        if let duration = fetched.durationSeconds {
            runs[idx].durationSeconds = duration
        }
        if !fetched.steps.isEmpty {
            runs[idx].steps = fetched.steps
        }
        recordCachedRunLogs(runID: run.id)
    }

    // MARK: - Secrets & Variables

    @discardableResult
    public func upsertSecret(repoFullName: String, name: String, value: String) async -> Bool {
        let key = canonicalRepoName(repoFullName)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanName.isEmpty, !value.isEmpty else { return false }
        guard await performRepoOperation(key, operation: { client, owner, repo in
            try await client.upsertActionSecret(owner: owner, repo: repo, name: cleanName, value: value)
        }) else { return false }
        var current = secretsByRepo[key] ?? []
        if let existingIdx = current.firstIndex(where: { $0.name == cleanName }) {
            current[existingIdx].updatedAtText = "刚刚"
        } else {
            current.append(RepoSecretItem(id: UUID().uuidString, name: cleanName, updatedAtText: "刚刚"))
        }
        secretsByRepo[key] = current
        showToast("密钥 \(cleanName) 已更新")
        return true
    }

    @discardableResult
    public func deleteSecret(repoFullName: String, id: String) async -> Bool {
        let key = canonicalRepoName(repoFullName)
        guard let target = secretsByRepo[key]?.first(where: { $0.id == id }) else { return false }
        guard await performRepoOperation(key, operation: { client, owner, repo in
            try await client.deleteActionSecret(owner: owner, repo: repo, name: target.name)
        }) else { return false }
        secretsByRepo[key]?.removeAll { $0.id == id }
        showToast("已删除密钥 \(target.name)")
        return true
    }

    @discardableResult
    public func upsertVariable(repoFullName: String, name: String, value: String) async -> Bool {
        let key = canonicalRepoName(repoFullName)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanName.isEmpty else { return false }
        var current = variablesByRepo[key] ?? []
        let exists = current.contains { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }
        guard await performRepoOperation(key, operation: { client, owner, repo in
            try await client.upsertActionVariable(
                owner: owner, repo: repo, name: cleanName, value: value, exists: exists
            )
        }) else { return false }
        if let idx = current.firstIndex(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) {
            current[idx].value = value
        } else {
            current.append(RepoVariableItem(id: UUID().uuidString, name: cleanName, value: value))
        }
        variablesByRepo[key] = current
        showToast("变量 \(cleanName) 已保存")
        return true
    }

    @discardableResult
    public func deleteVariable(repoFullName: String, id: String) async -> Bool {
        let key = canonicalRepoName(repoFullName)
        guard let target = variablesByRepo[key]?.first(where: { $0.id == id }) else { return false }
        guard await performRepoOperation(key, operation: { client, owner, repo in
            try await client.deleteActionVariable(owner: owner, repo: repo, name: target.name)
        }) else { return false }
        variablesByRepo[key]?.removeAll { $0.id == id }
        showToast("已删除变量 \(target.name)")
        return true
    }

    // MARK: - Widget Context & Snapshot Sync

    internal func buildAndSyncWidgetState(userDefaults: UserDefaults? = nil) {
        let context = WidgetConnectionContext(
            profileID: profile.id,
            displayName: profile.displayName,
            publicURL: profile.publicURL,
            lanURL: profile.lanURL,
            activeChannel: profile.activeChannel,
            username: profile.username,
            isDemoMode: isDemoMode
        )
        AppGroupBridge.saveWidgetConnectionContext(context, userDefaults: userDefaults)

        let runningRun = runs.first { $0.status == .running }
        let displayName = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let instanceName = isDemoMode ? "TeaPulse" : (displayName.isEmpty ? "TeaPulse" : displayName)
        let snapshot = WidgetDashboardSnapshot(
            instanceName: instanceName,
            probePillText: health.probePillText,
            serverVersion: health.serverVersion,
            unreadInboxCount: unreadInboxCount,
            runningBuildCount: runs.filter { $0.status == .running }.count,
            failedBuildCount: runs.filter { $0.status == .failure }.count,
            onlineRunnerCount: runners.filter { $0.status != .offline }.count,
            offlineRunnerCount: runners.filter { $0.status == .offline }.count,
            activeRunRepo: runningRun?.repoFullName,
            activeRunStep: runningRun?.steps.last?.name,
            heatmapDays: Array(heatmap.suffix(112)),
            triageItems: Array(triage.prefix(4))
        )
        AppGroupBridge.saveWidgetSnapshot(snapshot, userDefaults: userDefaults)
        #if canImport(WidgetKit)
        if userDefaults == nil {
            let triageSig = snapshot.triageItems.map { "\($0.id)|\($0.title)|\($0.metricText)" }.joined(separator: ",")
            let heatmapSum = snapshot.heatmapDays.reduce(0) { $0 + $1.contributions }
            let fingerprint = [
                profile.id, profile.publicURL, profile.lanURL ?? "", profile.activeChannel.rawValue,
                profile.username, "\(isDemoMode)", instanceName, health.probePillText, health.serverVersion,
                "\(snapshot.unreadInboxCount)", "\(snapshot.runningBuildCount)", "\(snapshot.failedBuildCount)",
                "\(snapshot.onlineRunnerCount)", "\(snapshot.offlineRunnerCount)",
                snapshot.activeRunRepo ?? "", snapshot.activeRunStep ?? "", triageSig,
                "\(snapshot.heatmapDays.count):\(heatmapSum)"
            ].joined(separator: "::")
            if fingerprint != lastSyncedWidgetFingerprint {
                lastSyncedWidgetFingerprint = fingerprint
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        #endif
    }
}
