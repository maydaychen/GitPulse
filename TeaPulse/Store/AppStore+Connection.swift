import Foundation
import GiteaKit

extension AppStore {
    public func switchToDemoMode() {
        connectionAttemptID = nil
        pendingRoute = nil
        let demo = DemoDataProvider.makeSnapshot()
        isDemoMode = true
        isLoginGatePresented = false
        profile = demo.profile
        proxyLatencyMs = 22
        lanLatencyMs = 3
        health = EndpointHealth(channel: .publicProxy, baseURL: demo.profile.publicURL, latencyMs: 22, serverVersion: "1.27.3")
        resetWorkspace(using: demo)
        showToast("已进入演示工作台")
        syncWidgetSnapshot()
    }

    internal func resetWorkspace(using demo: DemoSnapshot? = nil) {
        hasLoadedLiveWorkspace = false; isLoadingWorkspace = false; isResolvingRoute = false
        lastWorkspaceRefreshAt = nil; lastSyncedWidgetFingerprint = nil
        loadingRepoNames.removeAll(); loadedRepoNames.removeAll()
        loadingPRIDs.removeAll(); loadedPRIDs.removeAll()
        loadingRunIDs.removeAll(); loadedRunIDs.removeAll()
        loadedRepoTabTimestamps.removeAll(); commitDiffOrder.removeAll()
        loadedFileContentOrder.removeAll(); loadedRunLogOrder.removeAll()
        triage = demo?.triage ?? []
        pinnedRepos = demo?.pinnedRepos ?? []
        heatmap = demo?.heatmap ?? []
        activities = demo?.activities ?? []
        organizations = demo?.organizations ?? []
        repositories = demo?.repositories ?? []
        branchesByRepo = demo?.branchesByRepo ?? [:]
        commitsByRepo = demo?.commitsByRepo ?? [:]
        commitDiffsBySHA = demo?.commitDiffsBySHA ?? [:]
        selectedBranchByRepo = [:]
        selectedOrganizationFilter = nil
        repoFiles = demo?.repoFiles ?? [:]
        pullRequests = demo?.pullRequests ?? []
        issuesByRepo = demo?.issuesByRepo ?? [:]
        kanbanByRepo = demo?.kanbanByRepo ?? [:]
        releasesByRepo = demo?.releasesByRepo ?? [:]
        secretsByRepo = demo?.secretsByRepo ?? [:]
        variablesByRepo = demo?.variablesByRepo ?? [:]
        webhooksByRepo = demo?.webhooksByRepo ?? [:]
        runs = demo?.runs ?? []
        runners = demo?.runners ?? []
        notifications = demo?.notifications ?? []
        adminStats = demo?.adminStats ?? AdminOverviewStats(serverVersion: "未加载", totalUsers: 0, totalRepos: 0, activeRunners: 0, offlineRunners: 0, packageCount: 0)
        cronTasks = demo?.cronTasks ?? []
        adminUsers = demo?.adminUsers ?? []
        packages = demo?.packages ?? []
        selectedRepoID = repositories.first?.id
        selectedPRID = pullRequests.first?.id
        selectedRunID = runs.first?.id
        pendingInlineDrafts = [:]
        approvedPRIDs = []
        lastRunnerRegistrationToken = nil
        simulatedPushBanner = nil
        proxyLatencyMs = demo == nil ? 0 : 22
        lanLatencyMs = demo == nil ? 0 : 3
    }

    public func connectLiveInstance(
        displayName: String, publicURL: String, lanURL: String?, patToken: String,
        sshPortOverride: Int?, barkURL: String?, preferredChannel: EndpointChannel = .publicProxy,
        customHeaders: [String: String] = [:]
    ) async -> Bool {
        let attemptID = UUID()
        connectionAttemptID = attemptID
        defer {
            if connectionAttemptID == attemptID { connectionAttemptID = nil }
        }
        let cleanPublic = publicURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLAN = lanURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let token = patToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            showToast("请填写 PAT，未修改当前连接")
            return false
        }
        guard preferredChannel != .demo,
              (try? GiteaURLBuilder.apiURL(baseURLString: cleanPublic, endpointPath: "/user")) != nil,
              preferredChannel != .lanDirect || cleanLAN != nil else {
            showToast("请填写有效的实例地址与所选通道")
            return false
        }
        let baseURL = preferredChannel == .lanDirect ? (cleanLAN ?? cleanPublic) : cleanPublic
        let credentials = StoredCredentials(patToken: token, customHeaders: customHeaders)
        let client = GiteaClient(baseURL: baseURL, credentials: credentials, transport: transport)
        isLoadingWorkspace = true
        defer { if connectionAttemptID == nil || connectionAttemptID == attemptID { isLoadingWorkspace = false } }
        do {
            let loaded = try await loadLiveWorkspace(client: client)
            try Task.checkCancellation()
            guard connectionAttemptID == attemptID else { return false }
            let newProfile = InstanceProfile(
                id: UUID().uuidString, displayName: displayName.isEmpty ? "Gitea" : displayName,
                publicURL: cleanPublic, lanURL: cleanLAN, sshPortOverride: sshPortOverride,
                activeChannel: preferredChannel,
                barkEndpointURL: barkURL?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
                username: loaded.username
            )
            // Authenticate and load before persisting or dismissing the login gate.
            try credentialStore.saveCredentials(credentials, forProfileID: newProfile.id)
            let oldProfileID = isDemoMode ? nil : profile.id
            Self.saveProfile(newProfile, key: profileStorageKey, defaults: defaults)
            connectionAttemptID = nil
            profile = newProfile
            isDemoMode = false
            isLoginGatePresented = false
            resetWorkspace()
            applyLiveWorkspace(loaded)
            health = EndpointHealth(channel: preferredChannel, baseURL: baseURL, latencyMs: 0, serverVersion: loaded.version)
            if let oldProfileID, oldProfileID != newProfile.id {
                credentialStore.deleteCredentials(forProfileID: oldProfileID)
            }
            await refreshEndpointProbe()
            showToast("已接入 \(newProfile.displayName)")
            resolvePendingRoutes()
            return true
        } catch {
            guard !Task.isCancelled, connectionAttemptID == attemptID else { return false }
            showToast(error.localizedDescription)
            return false
        }
    }

    private struct LiveWorkspace {
        let version: String
        let username: String
        let heatmap: [HeatmapDay]
        let activities: [ActivityEvent]
        let organizations: [OrganizationSummary]
        let repositories: [RepositorySummary]
        let pullRequests: [PullRequestDetail]
        let notifications: [NotificationThread]
        let runs: [WorkflowRun]
        let runners: [RunnerNode]
        let cronTasks: [CronTaskItem]
        let adminUsers: [AdminUserItem]
    }

    private func loadLiveWorkspace(client: GiteaClient) async throws -> LiveWorkspace {
        async let version = client.fetchVersion()
        let currentLogin = try await client.fetchCurrentUserLogin()
        async let orgsTask = client.fetchUserOrganizations()
        async let starredTask = client.fetchStarredRepositories(currentUsername: currentLogin)
        let accessibleRepos = try await client.fetchAllAccessibleRepositories(currentUsername: currentLogin)
        let fetchedOrgs = (try? await orgsTask) ?? []
        let fetchedStarred = (try? await starredTask) ?? []
        var repos = fetchedOrgs.isEmpty
            ? accessibleRepos
            : await client.mergeOrganizationRepositories(
                organizations: fetchedOrgs,
                into: accessibleRepos,
                currentUsername: currentLogin
            )
        let orgOwners = Set(fetchedOrgs.map { $0.username.lowercased() })
        let starredIDs = Set(fetchedStarred.map(\.id))
        var seenRepoIDs = Set(repos.map(\.id))
        for idx in repos.indices where starredIDs.contains(repos[idx].id) {
            repos[idx].isStarred = true
        }
        for var starredRepo in fetchedStarred where seenRepoIDs.insert(starredRepo.id).inserted {
            if orgOwners.contains(starredRepo.owner.lowercased()) {
                starredRepo.isOrganizationOwned = true
                if !starredRepo.isMirror { starredRepo.scope = .org }
            }
            repos.append(starredRepo)
        }

        async let heatmapTask = client.fetchHeatmap(username: currentLogin)
        async let activitiesTask = client.fetchActivityFeeds(username: currentLogin)
        async let notificationsTask = client.fetchNotifications()
        async let cronTask = client.fetchAdminCronTasks()
        async let usersTask = client.fetchAdminUsers()

        let nonMirrorRepos = repos.filter { !$0.isMirror }
        let openPRTargets = nonMirrorRepos.filter { $0.openPRCount > 0 }
        let prQueryTargets = openPRTargets.isEmpty ? Array(nonMirrorRepos.prefix(3)) : Array(openPRTargets.prefix(8))

        async let prsTask = Self.fetchOpenPRsAndEnrich(targets: prQueryTargets, client: client)
        async let runsTask = Self.fetchRecentWorkflowRuns(repos: nonMirrorRepos, client: client)

        let prs = await prsTask
        let fetchedRuns = await runsTask
        let fetchedHeatmap = (try? await heatmapTask) ?? []
        var resolvedActivities = (try? await activitiesTask) ?? []
        if resolvedActivities.isEmpty {
            var seenOrgs = Set<String>()
            let orgCandidates = repos.filter { $0.scope == .org || $0.isOrganizationOwned }.map(\.owner)
                + fetchedOrgs.map(\.username)
            let orgs = orgCandidates.filter { seenOrgs.insert($0.lowercased()).inserted }
            resolvedActivities = await Self.fetchOrganizationFallbackActivities(orgs: orgs, client: client)
        }
        let mergedRepos = resolvedActivities.isEmpty ? repos : await client.mergeActivityRepositories(
            activities: resolvedActivities, into: repos, currentUsername: currentLogin
        )
        if resolvedActivities.isEmpty {
            resolvedActivities = GiteaClient.buildFallbackActivities(repositories: mergedRepos, pullRequests: prs)
        }
        let fetchedRunners = await client.fetchAvailableRunners(organizations: fetchedOrgs, repositories: mergedRepos)
        return try await LiveWorkspace(
            version: version, username: currentLogin, heatmap: fetchedHeatmap,
            activities: resolvedActivities, organizations: fetchedOrgs, repositories: mergedRepos,
            pullRequests: prs, notifications: (try? await notificationsTask) ?? [], runs: fetchedRuns,
            runners: fetchedRunners, cronTasks: (try? await cronTask) ?? [], adminUsers: (try? await usersTask) ?? []
        )
    }

    private func applyLiveWorkspace(_ loaded: LiveWorkspace) {
        let selectDefault = !hasLoadedLiveWorkspace && pendingRoute == nil
        hasLoadedLiveWorkspace = true
        lastWorkspaceRefreshAt = Date()
        loadedRepoTabTimestamps.removeAll()
        isLoadingWorkspace = false
        loadedPRIDs.formUnion(loaded.pullRequests.prefix(8).map(\.id))
        profile.username = loaded.username
        health.serverVersion = loaded.version
        heatmap = loaded.heatmap
        activities = loaded.activities
        organizations = loaded.organizations
        repositories = loaded.repositories
        if let activeOrg = selectedOrganizationFilter,
           !availableOrganizations.contains(where: { $0.username.caseInsensitiveCompare(activeOrg) == .orderedSame }) {
            selectedOrganizationFilter = nil
        }
        pullRequests = loaded.pullRequests
        notifications = loaded.notifications
        runs = loaded.runs
        runners = loaded.runners
        cronTasks = loaded.cronTasks
        adminUsers = loaded.adminUsers
        adminStats = AdminOverviewStats(
            serverVersion: loaded.version,
            totalUsers: loaded.adminUsers.isEmpty ? 1 : loaded.adminUsers.count,
            totalRepos: loaded.repositories.count,
            activeRunners: runners.filter { $0.status != .offline }.count,
            offlineRunners: runners.filter { $0.status == .offline }.count,
            packageCount: packages.count
        )
        rebuildPinnedRepos()

        var triageItems: [TriageItem] = loaded.pullRequests.filter { $0.state == .open }.map { pr in
            TriageItem(
                id: "tr-\(pr.id)", kind: .pullRequest, priority: 1, repoFullName: pr.repoFullName,
                title: pr.title, subtitlePill: "\(pr.headBranch) -> \(pr.baseBranch)",
                metricText: "+\(pr.additions) -\(pr.deletions)", deepLink: "teapulse://pull/\(pr.repoFullName)/\(pr.number)"
            )
        }
        for run in loaded.runs where run.status == .failure {
            if triageItems.count >= 10 { break }
            triageItems.append(
                TriageItem(
                    id: "tr-\(run.id)",
                    kind: .failedRun,
                    priority: triageItems.count + 1,
                    repoFullName: run.repoFullName,
                    title: "\(run.workflowName) #\(run.runNumber)",
                    subtitlePill: "\(run.branch) · \(run.runnerName)",
                    metricText: run.status.badgeLabel,
                    deepLink: "teapulse://actions/\(run.repoFullName)/\(run.runNumber)?step=failed"
                )
            )
        }
        for idx in triageItems.indices { triageItems[idx].priority = idx + 1 }
        triage = triageItems

        if selectDefault {
            selectedRepoID = repositories.first?.id
            selectedPRID = pullRequests.first?.id
            selectedRunID = runs.first?.id
        } else {
            if !repositories.contains(where: { $0.id == selectedRepoID }) { selectedRepoID = nil }
            if !pullRequests.contains(where: { $0.id == selectedPRID }) { selectedPRID = nil }
            if !runs.contains(where: { $0.id == selectedRunID }) { selectedRunID = nil }
        }
        syncWidgetSnapshot()
    }

    public func refreshLiveInstanceData() async {
        guard !isDemoMode else {
            await refreshEndpointProbe()
            return
        }
        guard let client = makeActiveClient() else {
            isLoadingWorkspace = false
            isLoginGatePresented = true
            return
        }
        let sessionID = profile.id
        if !hasLoadedLiveWorkspace { isLoadingWorkspace = true }
        defer { if !isDemoMode, profile.id == sessionID { isLoadingWorkspace = false } }
        do {
            let loaded = try await loadLiveWorkspace(client: client)
            guard !isDemoMode, profile.id == sessionID else { return }
            applyLiveWorkspace(loaded)
            Self.saveProfile(profile, key: profileStorageKey, defaults: defaults)
            resolvePendingRoutes()
            await refreshEndpointProbe()
        } catch {
            guard !isDemoMode, profile.id == sessionID else { return }
            showToast(error.localizedDescription)
        }
    }

    public var isInitialWorkspaceLoading: Bool { !isDemoMode && isLoadingWorkspace && !hasLoadedLiveWorkspace }

    public func isLoadingRepoDetails(_ repoFullName: String) -> Bool {
        guard !isDemoMode else { return false }
        let key = canonicalRepoName(repoFullName).lowercased()
        return isLoadingWorkspace || loadingRepoNames.contains(key) || !loadedRepoNames.contains(key)
    }

    public func isLoadingPRDetails(_ pr: PullRequestDetail) -> Bool {
        guard !isDemoMode else { return false }
        return isLoadingWorkspace || loadingPRIDs.contains(pr.id)
            || (!loadedPRIDs.contains(pr.id) && pr.files.isEmpty && pr.comments.isEmpty && pr.checks.isEmpty)
    }

    public func loadRepositoryDetails(repoFullName: String, directoryPath: String = "") async {
        guard !isDemoMode, let client = makeActiveClient(),
              let repo = repository(named: repoFullName) else { return }
        let canonicalName = repo.fullName
        let repoKey = canonicalName.lowercased()
        let activeRef = activeBranch(for: repo)
        let sessionID = profile.id
        loadingRepoNames.insert(repoKey)
        defer {
            loadingRepoNames.remove(repoKey)
            if !isDemoMode, profile.id == sessionID { loadedRepoNames.insert(repoKey) }
        }

        if directoryPath.isEmpty {
            async let prsTask = client.fetchPullRequests(owner: repo.owner, repo: repo.name)
            async let issuesTask = client.fetchIssues(owner: repo.owner, repo: repo.name)
            async let releasesTask = client.fetchReleases(owner: repo.owner, repo: repo.name)
            async let hooksTask = client.fetchWebhooks(owner: repo.owner, repo: repo.name)
            async let secretsTask = client.fetchActionSecrets(owner: repo.owner, repo: repo.name)
            async let varsTask = client.fetchActionVariables(owner: repo.owner, repo: repo.name)
            async let runsTask = client.fetchRepoWorkflowRuns(owner: repo.owner, repo: repo.name, defaultBranch: repo.defaultBranch)
            async let branchesTask = client.fetchRepoBranches(owner: repo.owner, repo: repo.name, defaultBranch: repo.defaultBranch)
            async let commitsTask = client.fetchRepoCommits(owner: repo.owner, repo: repo.name, sha: activeRef)

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
            guard !isDemoMode, profile.id == sessionID else { return }

            let readmeTarget = Self.preferredReadmeEntry(in: resolvedFiles)
            var loadedReadmeText: String?
            if let entry = readmeTarget {
                loadedReadmeText = try? await client.fetchRepoFileContent(
                    owner: repo.owner, repo: repo.name, path: entry.path, ref: activeRef
                )
                if let loadedReadmeText,
                   let matchIdx = resolvedFiles.firstIndex(where: { $0.path == entry.path }) {
                    resolvedFiles[matchIdx].content = loadedReadmeText
                }
            }

            let fetchedPRs = try? await prsTask
            let prs = await Self.enrichFirstPRs(fetchedPRs, owner: repo.owner, repo: repo.name, client: client)
            let issues = try? await issuesTask
            let releases = try? await releasesTask
            let hooks = try? await hooksTask
            let secrets = try? await secretsTask
            let variables = try? await varsTask
            let repoRuns = try? await runsTask
            let branches = try? await branchesTask
            let commits = try? await commitsTask
            guard !isDemoMode, profile.id == sessionID else { return }

            if let prs {
                loadedPRIDs.formUnion(prs.map(\.id))
                pullRequests.removeAll { $0.repoFullName.caseInsensitiveCompare(canonicalName) == .orderedSame }
                pullRequests.append(contentsOf: prs)
            }
            if let issues { issuesByRepo[canonicalName] = issues }
            if let releases { releasesByRepo[canonicalName] = releases }
            if let hooks { webhooksByRepo[canonicalName] = hooks }
            if let secrets { secretsByRepo[canonicalName] = secrets }
            if let variables { variablesByRepo[canonicalName] = variables }
            if let branches { branchesByRepo[canonicalName] = branches }
            if let commits { commitsByRepo[canonicalName] = commits }
            if let repoRuns, !repoRuns.isEmpty {
                runs.removeAll { $0.repoFullName.caseInsensitiveCompare(canonicalName) == .orderedSame }
                runs.insert(contentsOf: repoRuns, at: 0)
                rebuildPinnedRepos()
            }
            if let repoIdx = repositories.firstIndex(where: { $0.id == repo.id }) {
                repositories[repoIdx].readmeMarkdown = Self.buildReadmeText(
                    repo: repo, readmeEntry: readmeTarget, readmeText: loadedReadmeText,
                    files: resolvedFiles, contentError: contentError
                )
            }
            markAllRepoTabsLoaded(repoFullName: canonicalName, branch: activeRef)
            if let contentError {
                if case .httpStatus(404, _) = contentError as? GiteaClientError {} else { showToast(contentError.localizedDescription) }
            }
            repoFiles[canonicalName] = resolvedFiles
            return
        }

        var resolvedFiles: [RepoFileEntry]
        var contentError: Error?
        do {
            resolvedFiles = try await client.fetchRepoContents(owner: repo.owner, repo: repo.name, path: directoryPath, ref: activeRef)
        } catch {
            resolvedFiles = []; contentError = error
        }
        guard !isDemoMode, profile.id == sessionID else { return }
        if let contentError {
            if case .httpStatus(404, _) = contentError as? GiteaClientError {} else { showToast(contentError.localizedDescription) }
        }
        repoFiles[canonicalName] = resolvedFiles
    }

    public func makeActiveClient() -> GiteaClient? {
        guard !isDemoMode else { return nil }
        guard let credentials = credentialStore.loadCredentials(forProfileID: profile.id), !credentials.patToken.isEmpty else {
            showToast("凭据不可用，请重新连接实例")
            return nil
        }
        let base = profile.activeChannel == .lanDirect ? (profile.lanURL ?? profile.publicURL) : profile.publicURL
        return GiteaClient(baseURL: base, credentials: credentials, transport: transport)
    }

    internal func demoOnly(_ operation: String) -> Bool {
        guard isDemoMode else {
            showToast("\(operation)暂未接入服务器，仅演示模式可用")
            return false
        }
        return true
    }

    internal func performRepoOperation(
        _ fullName: String, operation: (GiteaClient, String, String) async throws -> Void
    ) async -> Bool {
        if isDemoMode { return true }
        let parts = fullName.split(separator: "/").map(String.init)
        guard parts.count == 2 else {
            showToast("仓库地址无效，未提交操作")
            return false
        }
        return await performLiveOperation { client in
            try await operation(client, parts[0], parts[1])
        }
    }

    internal func performLiveOperation(_ operation: (GiteaClient) async throws -> Void) async -> Bool {
        if isDemoMode { return true }
        guard let client = makeActiveClient() else { return false }
        let sessionID = profile.id
        do {
            try await operation(client)
            return !isDemoMode && profile.id == sessionID
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
