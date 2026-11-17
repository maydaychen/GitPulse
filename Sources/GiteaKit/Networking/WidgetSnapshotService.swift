import Foundation

/// Fetches lightweight live workspace telemetry directly from widget extensions using shared context and Keychain credentials.
public struct WidgetSnapshotService: Sendable {
    private let transport: HTTPTransport
    private let lanTimeoutSeconds: TimeInterval

    public init(transport: HTTPTransport = URLSessionHTTPTransport(), lanTimeoutSeconds: TimeInterval = 0.8) {
        self.transport = transport
        self.lanTimeoutSeconds = lanTimeoutSeconds
    }

    public func refreshSnapshot(
        context: WidgetConnectionContext?,
        credentialStore: CredentialStore,
        cachedSnapshot: WidgetDashboardSnapshot?,
        forceDemoTimestampUpdate: Bool = false,
        now: Date = Date()
    ) async -> WidgetDashboardSnapshot? {
        guard let context else { return cachedSnapshot }

        if context.isDemoMode {
            var base = cachedSnapshot ?? WidgetDashboardSnapshot.makePreview(now: now)
            if forceDemoTimestampUpdate || cachedSnapshot == nil {
                base.updatedAt = now
            }
            return base
        }

        guard !context.publicURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let credentials = credentialStore.loadCredentials(forProfileID: context.profileID),
              !credentials.patToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return cachedSnapshot
        }

        let probeProfile = InstanceProfile(
            id: context.profileID,
            displayName: context.displayName,
            publicURL: context.publicURL,
            lanURL: context.lanURL,
            activeChannel: context.activeChannel,
            username: context.username
        )
        let probeService = EndpointProbeService(transport: transport, lanTimeoutSeconds: lanTimeoutSeconds)
        guard let resolvedHealth = await resolveReachableEndpoint(
            for: probeProfile,
            probeService: probeService,
            headers: credentials.customHeaders
        ) else {
            return cachedSnapshot
        }

        let client = GiteaClient(
            baseURL: resolvedHealth.baseURL,
            credentials: credentials,
            transport: transport
        )

        let username: String
        if context.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let resolvedLogin = try? await client.fetchCurrentUserLogin() else {
                return cachedSnapshot
            }
            username = resolvedLogin
        } else {
            username = context.username
        }

        guard let repos = try? await client.fetchRepositories(page: 1, limit: 20, currentUsername: username) else {
            return cachedSnapshot
        }

        async let heatmapTask = client.fetchHeatmap(username: username)
        async let notificationsTask = client.fetchNotifications()
        async let orgsTask = client.fetchUserOrganizations()

        let fetchedHeatmap = (try? await heatmapTask) ?? cachedSnapshot?.heatmapDays ?? []
        let notifications = (try? await notificationsTask) ?? []
        let orgs = (try? await orgsTask) ?? []

        let nonMirrorRepos = repos.filter { !$0.isMirror }
        let prs = await fetchOpenPRs(client: client, repos: nonMirrorRepos)
        let runs = await fetchRecentRuns(client: client, repos: nonMirrorRepos)
        let runners = await client.fetchAvailableRunners(
            organizations: orgs,
            repositories: Array(repos.prefix(4))
        )

        let runningRun = runs.first { $0.status == .running }
        let triage = buildTriageItems(prs: prs, runs: runs, runners: runners)
        let instanceName = context.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "TeaPulse"
            : context.displayName

        return WidgetDashboardSnapshot(
            instanceName: instanceName,
            probePillText: resolvedHealth.probePillText,
            serverVersion: resolvedHealth.serverVersion,
            unreadInboxCount: notifications.filter(\.unread).count,
            runningBuildCount: runs.filter { $0.status == .running }.count,
            failedBuildCount: runs.filter { $0.status == .failure }.count,
            onlineRunnerCount: runners.filter { $0.status != .offline }.count,
            offlineRunnerCount: runners.filter { $0.status == .offline }.count,
            activeRunRepo: runningRun?.repoFullName,
            activeRunStep: runningRun?.steps.last?.name,
            heatmapDays: Array(fetchedHeatmap.suffix(112)),
            triageItems: Array(triage.prefix(4)),
            updatedAt: now
        )
    }

    private func resolveReachableEndpoint(
        for profile: InstanceProfile,
        probeService: EndpointProbeService,
        headers: [String: String]
    ) async -> EndpointHealth? {
        let cleanLAN = profile.lanURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if profile.activeChannel == .lanDirect && !cleanLAN.isEmpty {
            if let lan = await probeService.measureHealthz(
                baseURL: cleanLAN, channel: .lanDirect, timeout: lanTimeoutSeconds, additionalHeaders: headers
            ) {
                return lan
            }
            return await probeService.measureHealthz(
                baseURL: profile.publicURL, channel: .publicProxy, timeout: 3.5, additionalHeaders: headers
            )
        }

        if let proxy = await probeService.measureHealthz(
            baseURL: profile.publicURL, channel: .publicProxy, timeout: 3.5, additionalHeaders: headers
        ) {
            return proxy
        }
        if !cleanLAN.isEmpty {
            return await probeService.measureHealthz(
                baseURL: cleanLAN, channel: .lanDirect, timeout: lanTimeoutSeconds, additionalHeaders: headers
            )
        }
        return nil
    }

    private func fetchOpenPRs(client: GiteaClient, repos: [RepositorySummary]) async -> [PullRequestDetail] {
        let withOpenPR = repos.filter { $0.openPRCount > 0 }
        let targets = withOpenPR.isEmpty ? Array(repos.prefix(2)) : Array(withOpenPR.prefix(4))
        var results: [PullRequestDetail] = []
        for repo in targets {
            if let batch = try? await client.fetchPullRequests(owner: repo.owner, repo: repo.name) {
                results.append(contentsOf: batch.filter { $0.state == .open })
            }
        }
        return results
    }

    private func fetchRecentRuns(client: GiteaClient, repos: [RepositorySummary]) async -> [WorkflowRun] {
        var results: [WorkflowRun] = []
        for repo in repos.prefix(4) {
            if let batch = try? await client.fetchRepoWorkflowRuns(
                owner: repo.owner,
                repo: repo.name,
                defaultBranch: repo.defaultBranch
            ) {
                results.append(contentsOf: batch)
            }
        }
        return results
    }

    private func buildTriageItems(
        prs: [PullRequestDetail],
        runs: [WorkflowRun],
        runners: [RunnerNode]
    ) -> [TriageItem] {
        var items: [TriageItem] = []
        for pr in prs.prefix(3) {
            items.append(
                TriageItem(
                    id: "tr-\(pr.id)",
                    kind: .pullRequest,
                    priority: items.count + 1,
                    repoFullName: pr.repoFullName,
                    title: pr.title,
                    subtitlePill: "\(pr.headBranch) -> \(pr.baseBranch)",
                    metricText: "+\(pr.additions) -\(pr.deletions)",
                    deepLink: "teapulse://pull/\(pr.repoFullName)/\(pr.number)"
                )
            )
        }
        for run in runs where run.status == .failure && items.count < 4 {
            items.append(
                TriageItem(
                    id: "tr-\(run.id)",
                    kind: .failedRun,
                    priority: items.count + 1,
                    repoFullName: run.repoFullName,
                    title: "\(run.workflowName) #\(run.runNumber)",
                    subtitlePill: "\(run.branch) · \(run.runnerName)",
                    metricText: run.status.badgeLabel,
                    deepLink: "teapulse://actions/\(run.repoFullName)/\(run.runNumber)?step=failed"
                )
            )
        }
        for runner in runners where runner.status == .offline && items.count < 4 {
            items.append(
                TriageItem(
                    id: "tr-\(runner.id)",
                    kind: .offlineRunner,
                    priority: items.count + 1,
                    repoFullName: "act_runner",
                    title: "\(runner.name) 离线",
                    subtitlePill: "离线",
                    metricText: runner.version,
                    deepLink: "teapulse://ops/runners"
                )
            )
        }
        return items
    }
}
