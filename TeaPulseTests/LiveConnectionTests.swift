import Foundation
import Testing
@testable import TeaPulse
import GiteaKit

private struct ConnectionTransport: HTTPTransport {
    let status: Int
    var failsNetwork = false

    func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData {
        if failsNetwork { throw GiteaClientError.networkFailure("offline") }
        let path = request.url?.path ?? ""
        let body: String
        switch path {
        case "/api/healthz", "/api/v1/version": body = #"{"version":"1.27.3"}"#
        case "/api/v1/user": body = #"{"login":"tester"}"#
        case "/api/v1/user/repos": body = "[]"
        default: body = "{}"
        }
        return HTTPResponseData(statusCode: status, body: Data(body.utf8))
    }
}

@MainActor
@Suite("Live connection isolation")
struct LiveConnectionTests {
    private func store(status: Int = 200) -> AppStore {
        let defaults = UserDefaults(suiteName: "teapulse.test.\(UUID().uuidString)")!
        return AppStore(credentialStore: InMemoryCredentialStore(), transport: ConnectionTransport(status: status),
                        forceDemoMode: true, defaults: defaults, writesWidgetSnapshot: false)
    }

    @Test("Rejected PAT keeps the previous session and login gate")
    func rejectedPAT() async {
        let store = store(status: 401)
        store.isLoginGatePresented = true
        let previous = store.profile
        let connected = await store.connectLiveInstance(displayName: "Test", publicURL: "https://git.example.com",
            lanURL: nil, patToken: "synthetic-test-pat", sshPortOverride: nil, barkURL: nil)
        #expect(!connected)
        #expect(store.isDemoMode)
        #expect(store.isLoginGatePresented)
        #expect(store.profile == previous)
        #expect(store.credentialStore.loadCredentials(forProfileID: "primary-gitea") == nil)
    }

    @Test("An empty real account replaces every demo collection")
    func emptyLiveAccount() async {
        let store = store()
        let connected = await store.connectLiveInstance(displayName: "Test", publicURL: "https://git.example.com",
            lanURL: nil, patToken: "synthetic-test-pat", sshPortOverride: nil, barkURL: nil)
        #expect(connected)
        #expect(!store.isDemoMode)
        #expect(store.organizations.isEmpty)
        #expect(store.repositories.isEmpty)
        #expect(store.pullRequests.isEmpty)
        #expect(store.activities.isEmpty)
        #expect(store.pinnedRepos.isEmpty)
        #expect(store.triage.isEmpty)
        #expect(store.runs.isEmpty)
        #expect(store.notifications.isEmpty)
        #expect(store.secretsByRepo.isEmpty)
        #expect(store.adminUsers.isEmpty)
        store.pullRequests = DemoDataProvider.makeSnapshot().pullRequests
        await store.refreshLiveInstanceData()
        #expect(store.pullRequests.isEmpty)
    }

    @Test("Empty PAT and invalid URL cannot reuse a previous credential")
    func invalidInput() async throws {
        let store = store()
        let previous = store.profile
        try store.credentialStore.saveCredentials(StoredCredentials(patToken: "old-test-pat"), forProfileID: previous.id)
        for input in [("https://git.example.com", ""), ("invalid", "synthetic-test-pat")] {
            let connected = await store.connectLiveInstance(displayName: "Test", publicURL: input.0,
                lanURL: nil, patToken: input.1, sshPortOverride: nil, barkURL: nil)
            #expect(!connected)
            #expect(store.profile == previous)
            #expect(store.credentialStore.loadCredentials(forProfileID: previous.id)?.patToken == "old-test-pat")
        }
    }

    @Test("Network failure and Keychain failure leave the saved session intact")
    func persistenceFailures() async {
        for failsNetwork in [true, false] {
            let defaults = UserDefaults(suiteName: "teapulse.test.\(UUID().uuidString)")!
            let previous = InstanceProfile(id: "old", displayName: "Previous", publicURL: "https://old.example.com")
            AppStore.saveProfile(previous, key: "teapulse.saved.profile.v1", defaults: defaults)
            let store = AppStore(credentialStore: FailingCredentialStore(),
                transport: ConnectionTransport(status: 200, failsNetwork: failsNetwork),
                defaults: defaults, writesWidgetSnapshot: false)
            let connected = await store.connectLiveInstance(displayName: "Test", publicURL: "https://git.example.com",
                lanURL: nil, patToken: "synthetic-test-pat", sshPortOverride: nil, barkURL: nil)
            #expect(!connected)
            #expect(store.profile == previous)
            let saved = defaults.data(forKey: "teapulse.saved.profile.v1")!
            #expect((try? JSONDecoder().decode(InstanceProfile.self, from: saved)) == previous)
        }
    }

    @Test("Relaunch starts empty and reloads the saved live account")
    func relaunch() async throws {
        let original = store()
        let connected = await original.connectLiveInstance(displayName: "Test", publicURL: "https://git.example.com",
            lanURL: nil, patToken: "synthetic-test-pat", sshPortOverride: nil, barkURL: nil)
        #expect(connected)
        let relaunched = AppStore(credentialStore: original.credentialStore, transport: ConnectionTransport(status: 200),
            defaults: original.defaults, writesWidgetSnapshot: false)
        #expect(!relaunched.isDemoMode)
        #expect(relaunched.repositories.isEmpty)
        #expect(relaunched.runs.isEmpty)
        #expect(relaunched.notifications.isEmpty)
        await relaunched.refreshLiveInstanceData()
        #expect(relaunched.profile.username == "tester")
        #expect(relaunched.repositories.isEmpty)
        relaunched.credentialStore.deleteCredentials(forProfileID: relaunched.profile.id)
        await relaunched.refreshLiveInstanceData()
        #expect(relaunched.isLoginGatePresented)
    }

    @Test("Missing credentials and API rejection cannot mutate review or inbox state")
    func rejectedWrites() async throws {
        for hasCredentials in [false, true] {
            let store = store(status: 403)
            store.isDemoMode = false
            if hasCredentials {
                try store.credentialStore.saveCredentials(StoredCredentials(patToken: "synthetic-test-pat"), forProfileID: store.profile.id)
            }
            let previousPR = store.pullRequests[0]
            store.addInlineReviewDraft(prID: previousPR.id, filePath: "App.swift", lineNumber: 12, body: "Keep draft")
            let submitted = await store.submitPRReview(prID: previousPR.id, decision: .approve, summary: "Test")
            #expect(!submitted)
            await store.toggleApprovePR(previousPR.id)
            await store.mergePullRequest(prID: previousPR.id, strategy: .squash)
            #expect(store.pendingInlineDrafts[previousPR.id]?.count == 1)
            #expect(store.pullRequests[0] == previousPR)
            #expect(store.approvedPRIDs.isEmpty)
            let unread = store.notifications.first(where: \.unread)!
            await store.markThreadRead(unread.id)
            await store.markAllThreadsRead()
            #expect(store.notifications.first(where: { $0.id == unread.id })?.unread == true)
            await store.generateRunnerRegistrationToken()
            #expect(store.lastRunnerRegistrationToken == nil)
        }
    }

    @Test("Live mode refuses unimplemented writes and never fabricates dispatch results")
    func unsupportedAndQueuedOperations() async throws {
        let store = store()
        store.isDemoMode = false
        try store.credentialStore.saveCredentials(StoredCredentials(patToken: "synthetic-test-pat"), forProfileID: store.profile.id)
        let repo = store.repositories[0].fullName
        let secrets = store.secretsByRepo[repo] ?? []
        if let firstSecret = secrets.first {
            #expect(await store.deleteSecret(repoFullName: repo, id: firstSecret.id) == true)
            #expect(store.secretsByRepo[repo]?.contains(where: { $0.id == firstSecret.id }) == false)
        }
        #expect(await store.upsertVariable(repoFullName: repo, name: "NEW", value: "value") == true)
        if let createdVar = store.variablesByRepo[repo]?.first(where: { $0.name == "NEW" }) {
            #expect(createdVar.value == "value")
            #expect(await store.deleteVariable(repoFullName: repo, id: createdVar.id) == true)
        }
        let run = store.runs[0]
        store.updateRunStatus(runID: run.id, to: .running)
        #expect(store.runs[0] == run)
        let count = store.runs.count
        await store.dispatchWorkflow(run: run, ref: "main", inputs: [:])
        #expect(store.runs.count == count)
        #expect(store.statusToast?.contains("待服务器确认") == true)
        let hookRepo = store.webhooksByRepo.keys.sorted().first!
        let hook = store.webhooksByRepo[hookRepo]![0]
        await store.replayWebhook(repoFullName: hookRepo, hookID: hook.id)
        #expect(store.webhooksByRepo[hookRepo]![0] == hook)
        store.triggerSimulatedBarkBanner()
        #expect(store.simulatedPushBanner == nil)
        store.switchToDemoMode()
        #expect(!store.runs.isEmpty)
        #expect(!store.repoFiles.isEmpty)
    }

    @Test("Gateway headers propagate to probes, manual channel persists, and Diff/Heatmap load")
    func gatewayHeadersChannelDiffHeatmapAndBarkPersistence() async throws {
        let defaults = UserDefaults(suiteName: "teapulse.test.\(UUID().uuidString)")!
        let unconfigured = AppStore(credentialStore: InMemoryCredentialStore(),
                                    transport: ProtectedWorkspaceTransport(),
                                    defaults: defaults,
                                    writesWidgetSnapshot: false)
        #expect(unconfigured.proxyLatencyMs == 0)
        #expect(unconfigured.lanLatencyMs == 0)

        let badHandshake = await unconfigured.runOnboardingHandshake(
            publicURL: "https://git.example.com:8443",
            lanURL: nil,
            patToken: "synthetic-test-pat",
            preferredChannel: .publicProxy,
            customHeaders: [:]
        )
        #expect(badHandshake.first(where: { $0.id == "s2" })?.state == .warning)

        let goodHeaders = ["CF-Access-Client-Id": "gate-1"]
        let okHandshake = await unconfigured.runOnboardingHandshake(
            publicURL: "https://git.example.com:8443",
            lanURL: "http://10.0.0.18:23000",
            patToken: "synthetic-test-pat",
            preferredChannel: .publicProxy,
            customHeaders: goodHeaders
        )
        #expect(okHandshake.allSatisfy { $0.state == .passed })

        let connected = await unconfigured.connectLiveInstance(
            displayName: "Prod",
            publicURL: "https://git.example.com:8443",
            lanURL: "http://10.0.0.18:23000",
            patToken: "synthetic-test-pat",
            sshPortOverride: 2222,
            barkURL: nil,
            preferredChannel: .publicProxy,
            customHeaders: goodHeaders
        )
        #expect(connected)
        #expect(unconfigured.health.latencyMs >= 1)
        #expect(unconfigured.proxyLatencyMs >= 1)
        #expect(unconfigured.lanLatencyMs >= 1)
        #expect(unconfigured.health.channel == .publicProxy)
        #expect(unconfigured.health.serverVersion == "1.27.3")
        #expect(unconfigured.repositories.first?.scope == .org)
        #expect(unconfigured.heatmap.count == 1)
        #expect(unconfigured.pullRequests.first?.files.first?.path == "App.swift")

        await unconfigured.refreshEndpointProbe()
        #expect(unconfigured.profile.activeChannel == .publicProxy)
        #expect(unconfigured.health.channel == .publicProxy)

        await unconfigured.selectEndpointChannel(.lanDirect)
        #expect(unconfigured.profile.activeChannel == .lanDirect)
        #expect(unconfigured.health.channel == .lanDirect)

        unconfigured.updateBarkEndpoint("https://bark.custom.test/push")
        let relaunched = AppStore(credentialStore: unconfigured.credentialStore,
                                  transport: ProtectedWorkspaceTransport(),
                                  defaults: defaults,
                                  writesWidgetSnapshot: false)
        #expect(relaunched.profile.barkEndpointURL == "https://bark.custom.test/push")
    }

    @Test("Failed repo and PR mutations return false")
    func failedMutationReturnValues() async throws {
        let store = store(status: 403)
        store.isDemoMode = false
        try store.credentialStore.saveCredentials(StoredCredentials(patToken: "synthetic-test-pat"), forProfileID: store.profile.id)
        let repo = store.repositories[0].fullName
        let prID = store.pullRequests[0].id
        #expect(await store.upsertSecret(repoFullName: repo, name: "TOKEN", value: "val") == false)
        if let secretID = store.secretsByRepo[repo]?.first?.id {
            #expect(await store.deleteSecret(repoFullName: repo, id: secretID) == false)
        }
        #expect(await store.upsertVariable(repoFullName: repo, name: "KEY", value: "val") == false)
        if let varID = store.variablesByRepo[repo]?.first?.id {
            #expect(await store.deleteVariable(repoFullName: repo, id: varID) == false)
        }
        #expect(await store.mergePullRequest(prID: prID, strategy: .squash) == false)
        #expect(await store.generateRunnerRegistrationToken() == false)
    }

    @Test("Opening a live repository loads README, directory files, PRs, issues, releases, and webhooks")
    func loadRepositoryDetailsPopulatesWorkspace() async throws {
        let defaults = UserDefaults(suiteName: "teapulse.test.\(UUID().uuidString)")!
        let store = AppStore(credentialStore: InMemoryCredentialStore(),
                             transport: RepoDetailsTransport(),
                             defaults: defaults,
                             writesWidgetSnapshot: false)
        let connected = await store.connectLiveInstance(
            displayName: "Prod",
            publicURL: "https://git.example.com:8443",
            lanURL: nil,
            patToken: "synthetic-test-pat",
            sshPortOverride: nil,
            barkURL: nil
        )
        #expect(connected)
        #expect(store.repositories.first?.readmeMarkdown == "README 暂未加载")

        await store.loadRepositoryDetails(repoFullName: "octo/engineering-wiki")
        #expect(store.repositories.first?.readmeMarkdown == "# engineering-wiki\n\nLive documentation.")
        #expect(store.repoFiles["octo/engineering-wiki"]?.count == 2)
        #expect(store.repoFiles["octo/engineering-wiki"]?.first(where: { $0.path == "docs" })?.isDirectory == true)
        #expect(store.repoFiles["octo/engineering-wiki"]?.first(where: { $0.path == "README.md" })?.content == "# engineering-wiki\n\nLive documentation.")
        #expect(store.pullRequests.contains(where: { $0.repoFullName == "octo/engineering-wiki" && $0.number == 3 }))
        #expect(store.issuesByRepo["octo/engineering-wiki"]?.first?.number == 5)
        #expect(store.releasesByRepo["octo/engineering-wiki"]?.first?.tagName == "v1.0.0")
        #expect(store.webhooksByRepo["octo/engineering-wiki"]?.first?.targetURL == "https://hooks.example.com")

        await store.loadRepositoryFileContent(repoFullName: "octo/engineering-wiki", filePath: "README.md")
        #expect(store.repoFiles["octo/engineering-wiki"]?.first(where: { $0.path == "README.md" })?.content == "# engineering-wiki\n\nLive documentation.")
    }

    @Test("Live workspace populates dashboard activities, org fallback feeds, pinned repos, and PR triage")
    func liveDashboardPopulatesActivitiesPinnedReposAndTriage() async {
        for useOrgFallback in [false, true] {
            let defaults = UserDefaults(suiteName: "teapulse.test.\(UUID().uuidString)")!
            let store = AppStore(
                credentialStore: InMemoryCredentialStore(),
                transport: DashboardFeedsTransport(useOrgFallback: useOrgFallback),
                defaults: defaults,
                writesWidgetSnapshot: false
            )
            let connected = await store.connectLiveInstance(
                displayName: "Prod",
                publicURL: "https://git.example.com:8443",
                lanURL: nil,
                patToken: "synthetic-test-pat",
                sshPortOverride: nil,
                barkURL: nil
            )
            #expect(connected)
            #expect(store.pinnedRepos.count == 1)
            #expect(store.pinnedRepos.first?.fullName == "ops-org/core")
            #expect(store.triage.count == 1)
            #expect(store.triage.first?.kind == .pullRequest)
            #expect(store.triage.first?.deepLink == "teapulse://pull/ops-org/core/12")
            #expect(store.activities.count == 1)
            if useOrgFallback {
                #expect(store.activities.first?.actor == "ops-bot")
                #expect(store.activities.first?.actionLabel == "镜像同步推送")
            } else {
                #expect(store.activities.first?.actor == "alex")
                #expect(store.activities.first?.actionLabel == "推送提交：fix: pulse feed")
            }
        }
    }

    @Test("Preloads activity repositories and resolves unloaded repo/PR deep links on demand")
    func preloadsActivityReposAndResolvesMissingDeepLinks() async {
        let defaults = UserDefaults(suiteName: "teapulse.test.\(UUID().uuidString)")!
        let store = AppStore(
            credentialStore: InMemoryCredentialStore(),
            transport: LazyDeepLinkTransport(),
            defaults: defaults,
            writesWidgetSnapshot: false
        )
        let connected = await store.connectLiveInstance(
            displayName: "Prod",
            publicURL: "https://git.example.com:8443",
            lanURL: nil,
            patToken: "synthetic-test-pat",
            sshPortOverride: nil,
            barkURL: nil
        )
        #expect(connected)
        #expect(store.repositories.contains(where: { $0.fullName == "acme-cloud/storefront" }))

        store.handle(deepLinkString: "teapulse://repo/Acme-Cloud/Storefront")
        #expect(store.selectedSection == .repos)
        #expect(store.selectedRepository?.fullName == "acme-cloud/storefront")
        #expect(store.statusToast?.contains("未找到") != true)

        await store.resolveLiveRoute(.repository(owner: "archive", repo: "late-repo"))
        #expect(store.selectedRepository?.fullName == "archive/late-repo")
        #expect(store.selectedSection == .repos)

        await store.resolveLiveRoute(.pullRequest(owner: "archive", repo: "late-repo", index: 9))
        #expect(store.selectedPullRequest?.number == 9)
        #expect(store.selectedRepoTab == .pullRequests)
        #expect(store.statusToast?.contains("未找到") != true)
    }
}

private struct LazyDeepLinkTransport: HTTPTransport {
    func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData {
        let path = request.url?.path ?? ""
        let body: String
        switch path {
        case "/api/healthz", "/api/v1/version": body = #"{"version":"1.27.3"}"#
        case "/api/v1/user": body = #"{"login":"octo"}"#
        case "/api/v1/user/repos":
            body = #"[{"id":1,"name":"core","full_name":"octo/core","owner":{"login":"octo","type":"User"},"default_branch":"main"}]"#
        case "/api/v1/users/octo/activities/feeds":
            body = #"[{"id":11,"op_type":"commit_repo","act_user":{"login":"octo"},"repo":{"name":"storefront","full_name":"acme-cloud/storefront"},"ref_name":"refs/heads/master","content":"{\"Commits\":[{\"Message\":\"chore: sync docs\"}]}","created":"2026-11-14T06:47:00Z"}]"#
        case "/api/v1/repos/acme-cloud/storefront":
            body = #"{"id":22,"name":"storefront","full_name":"acme-cloud/storefront","owner":{"login":"acme-cloud","type":"Organization"},"default_branch":"master"}"#
        case "/api/v1/repos/archive/late-repo":
            body = #"{"id":33,"name":"late-repo","full_name":"archive/late-repo","owner":{"login":"archive","type":"Organization"},"default_branch":"main"}"#
        case "/api/v1/repos/archive/late-repo/pulls":
            body = #"[{"id":9,"number":9,"title":"Late PR","state":"open","mergeable":true,"additions":2,"deletions":1,"user":{"login":"octo"},"head":{"label":"fix"},"base":{"label":"main"}}]"#
        default:
            body = "[]"
        }
        return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
    }
}

private struct DashboardFeedsTransport: HTTPTransport {
    let useOrgFallback: Bool

    func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData {
        let path = request.url?.path ?? ""
        let body: String
        switch path {
        case "/api/healthz", "/api/v1/version": body = #"{"version":"1.27.3"}"#
        case "/api/v1/user": body = #"{"login":"alex"}"#
        case "/api/v1/user/repos":
            body = #"[{"id":1,"name":"core","full_name":"ops-org/core","owner":{"login":"ops-org","type":"Organization"},"default_branch":"main","open_pr_counter":1,"mirror":false}]"#
        case "/api/v1/repos/ops-org/core/pulls":
            body = #"[{"id":9,"number":12,"title":"Fix probe","state":"open","mergeable":true,"additions":4,"deletions":1,"user":{"login":"alex"},"head":{"label":"feat"},"base":{"label":"main"}}]"#
        case "/api/v1/repos/ops-org/core/pulls/12.diff":
            body = "diff --git a/App.swift b/App.swift\n--- a/App.swift\n+++ b/App.swift\n@@ -1 +1 @@\n-old\n+new\n"
        case "/api/v1/users/alex/activities/feeds":
            body = useOrgFallback
                ? "[]"
                : #"[{"id":1,"op_type":"commit_repo","act_user":{"login":"alex"},"repo":{"name":"core","full_name":"ops-org/core"},"ref_name":"refs/heads/main","content":"{\"Commits\":[{\"Message\":\"fix: pulse feed\"}]}","created":"2026-11-14T15:30:00Z"}]"#
        case "/api/v1/orgs/ops-org/activities/feeds":
            body = #"[{"id":2,"op_type":"mirror_sync_push","act_user":{"login":"ops-bot"},"repo":{"name":"core","full_name":"ops-org/core"},"ref_name":"refs/heads/main","created":"2026-11-14T14:00:00Z"}]"#
        default:
            body = "[]"
        }
        return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
    }
}

private struct RepoDetailsTransport: HTTPTransport {
    func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData {
        let path = request.url?.path ?? ""
        let readmeEncoded = Data("# engineering-wiki\n\nLive documentation.".utf8).base64EncodedString()
        let body: String
        switch path {
        case "/api/healthz", "/api/v1/version": body = #"{"version":"1.27.3"}"#
        case "/api/v1/user": body = #"{"login":"octo"}"#
        case "/api/v1/user/repos":
            body = #"[{"id":11,"name":"engineering-wiki","full_name":"octo/engineering-wiki","owner":{"login":"octo","type":"User"},"default_branch":"main","mirror":false}]"#
        case "/api/v1/repos/octo/engineering-wiki/contents":
            body = #"[{"name":"README.md","path":"README.md","sha":"r1","type":"file","size":31},{"name":"docs","path":"docs","sha":"d1","type":"dir","size":0}]"#
        case "/api/v1/repos/octo/engineering-wiki/contents/README.md":
            body = #"{"name":"README.md","path":"README.md","sha":"r1","type":"file","size":31,"encoding":"base64","content":"\#(readmeEncoded)"}"#
        case "/api/v1/repos/octo/engineering-wiki/pulls":
            body = #"[{"id":3,"number":3,"title":"Update docs","state":"open","mergeable":true,"additions":4,"deletions":1,"user":{"login":"octo"},"head":{"label":"docs"},"base":{"label":"main"}}]"#
        case "/api/v1/repos/octo/engineering-wiki/pulls/3.diff":
            body = "diff --git a/README.md b/README.md\n--- a/README.md\n+++ b/README.md\n@@ -1 +1 @@\n-old\n+new\n"
        case "/api/v1/repos/octo/engineering-wiki/issues":
            body = #"[{"number":5,"title":"Add FAQ","state":"open","user":{"login":"octo"},"labels":[],"updated_at":"2026-11-14T12:00:00Z"}]"#
        case "/api/v1/repos/octo/engineering-wiki/releases":
            body = #"[{"id":8,"tag_name":"v1.0.0","name":"Initial Wiki","published_at":"2026-11-14T10:00:00Z","prerelease":false,"assets":[]}]"#
        case "/api/v1/repos/octo/engineering-wiki/hooks":
            body = #"[{"id":2,"active":true,"events":["push"],"config":{"url":"https://hooks.example.com"}}]"#
        default:
            body = "[]"
        }
        return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
    }
}

private struct ProtectedWorkspaceTransport: HTTPTransport {
    func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData {
        guard request.value(forHTTPHeaderField: "CF-Access-Client-Id") == "gate-1" else {
            return HTTPResponseData(statusCode: 403, body: Data("Forbidden".utf8))
        }
        let path = request.url?.path ?? ""
        switch path {
        case "/api/healthz":
            return HTTPResponseData(statusCode: 200, body: Data(#"{"status":"pass"}"#.utf8))
        case "/api/v1/version":
            return HTTPResponseData(statusCode: 200, body: Data(#"{"version":"1.27.3"}"#.utf8))
        case "/api/v1/user":
            return HTTPResponseData(statusCode: 200, body: Data(#"{"login":"alex"}"#.utf8))
        case "/api/v1/users/alex/heatmap":
            return HTTPResponseData(statusCode: 200, body: Data(#"[{"timestamp":1731542400,"contributions":4}]"#.utf8))
        case "/api/v1/user/repos":
            return HTTPResponseData(statusCode: 200, body: Data(#"[{"id":1,"name":"core","full_name":"ops-org/core","owner":{"login":"ops-org","type":"Organization"},"mirror":false}]"#.utf8))
        case "/api/v1/repos/ops-org/core/pulls":
            return HTTPResponseData(statusCode: 200, body: Data(#"[{"id":9,"number":12,"title":"Fix probe","state":"open","mergeable":true,"additions":1,"deletions":0,"user":{"login":"alex"},"head":{"label":"feat"},"base":{"label":"main"}}]"#.utf8))
        case "/api/v1/repos/ops-org/core/pulls/12.diff":
            let diff = "diff --git a/App.swift b/App.swift\n--- a/App.swift\n+++ b/App.swift\n@@ -1,1 +1,2 @@\n let x = 1\n+let y = 2\n"
            return HTTPResponseData(statusCode: 200, body: Data(diff.utf8))
        default:
            return HTTPResponseData(statusCode: 200, body: Data("{}".utf8))
        }
    }
}

private struct FailingCredentialStore: CredentialStore {
    func saveCredentials(_ credentials: StoredCredentials, forProfileID profileID: String) throws {
        throw GiteaClientError.networkFailure("Keychain unavailable")
    }
    func loadCredentials(forProfileID profileID: String) -> StoredCredentials? { nil }
    func deleteCredentials(forProfileID profileID: String) {}
}
