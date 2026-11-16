import Foundation
import Testing
@testable import TeaPulse
@testable import GiteaKit

@MainActor
@Suite("TeaPulseAppStoreTests")
struct AppStoreTests {
    @Test("Deep links navigate accurately across PR, failed Actions, Runners, and Repo")
    func handlesDeepLinks() {
        let store = AppStore(credentialStore: InMemoryCredentialStore(), forceDemoMode: true, defaults: UserDefaults(suiteName: "teapulse.test.\(UUID().uuidString)")!, writesWidgetSnapshot: false)

        store.handle(deepLinkString: "teapulse://pull/alex/teapulse-core/42")
        #expect(store.selectedSection == .repos)
        #expect(store.selectedRepoTab == .pullRequests)
        #expect(store.selectedPRSegment == .diff)
        #expect(store.selectedPullRequest?.number == 42)

        store.handle(deepLinkString: "teapulse://actions/alex/web-deploy/184?step=failed")
        #expect(store.selectedSection == .actions)
        #expect(store.selectedRun?.runNumber == 184)
        #expect(store.selectedRun?.steps.first(where: { $0.status == .failure })?.isExpanded == true)

        store.handle(deepLinkString: "teapulse://ops/runners")
        #expect(store.selectedSection == .actions)
        #expect(store.actionsFilter == .runners)

        store.handle(deepLinkString: "teapulse://repo/ops/nginx-gateway")
        #expect(store.selectedSection == .repos)
        #expect(store.selectedRepository?.fullName == "ops/nginx-gateway")
    }

    @Test("Merging stacked PR #42 advances PR #43 base branch")
    func mergesStackedPR() async {
        let store = AppStore(credentialStore: InMemoryCredentialStore(), forceDemoMode: true, defaults: UserDefaults(suiteName: "teapulse.test.\(UUID().uuidString)")!, writesWidgetSnapshot: false)
        store.addInlineReviewDraft(prID: "pr-42", filePath: "App.swift", lineNumber: 12, body: "LGTM")
        await store.submitPRReview(prID: "pr-42", decision: .approve, summary: "Ship")
        await store.mergePullRequest(prID: "pr-42", strategy: .squash)

        #expect(store.pullRequests.first(where: { $0.id == "pr-42" })?.state == .merged)
        #expect(store.pullRequests.first(where: { $0.id == "pr-43" })?.baseBranch == "main")
    }

    @Test("Supports mirror sync, webhook replay, secret CRUD, inbox read, and cron trigger")
    func exercisesOpsMutations() async {
        let store = AppStore(credentialStore: InMemoryCredentialStore(), forceDemoMode: true, defaults: UserDefaults(suiteName: "teapulse.test.\(UUID().uuidString)")!, writesWidgetSnapshot: false)

        await store.upsertSecret(repoFullName: "alex/teapulse-core", name: "NEW_TOKEN", value: "demo-secret")
        #expect(store.secretsByRepo["alex/teapulse-core"]?.contains(where: { $0.name == "NEW_TOKEN" }) == true)

        await store.triggerMirrorSync(repoID: "repo-4")
        #expect(store.repositories.first(where: { $0.id == "repo-4" })?.lastMirrorSyncText == "刚刚")

        await store.replayWebhook(repoFullName: "alex/teapulse-core", hookID: "wh-1")
        #expect(store.webhooksByRepo["alex/teapulse-core"]?.first?.lastStatusCode == 200)

        let beforeUnread = store.unreadInboxCount
        await store.markThreadRead("not-1")
        #expect(store.unreadInboxCount == beforeUnread - 1)

        await store.markAllThreadsRead()
        #expect(store.unreadInboxCount == 0)

        await store.selectEndpointChannel(.lanDirect)
        #expect(store.health.channel == .lanDirect)

        await store.toggleApprovePR("pr-42")
        #expect(store.approvedPRIDs.contains("pr-42"))

        store.triggerSimulatedBarkBanner()
        #expect(store.simulatedPushBanner != nil)

        await store.triggerCronTask("cron-1")
        #expect(store.cronTasks.first?.lastRunText == "刚刚")
    }

    @Test("Live workspace loads notifications/runs/admin/secrets/vars/comments/checks and resolves case-insensitive action routes")
    func loadsLiveWorkspaceExtensionsAndActionRoutes() async {
        struct RichTransport: HTTPTransport {
            func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData {
                let path = request.url?.path ?? ""
                let body: String
                switch path {
                case "/api/healthz", "/api/v1/version": body = #"{"version":"1.27.3"}"#
                case "/api/v1/user": body = #"{"login":"Alex"}"#
                case "/api/v1/user/repos":
                    body = #"[{"id":10,"name":"Web-Deploy","full_name":"Alex/Web-Deploy","owner":{"login":"Alex","type":"User"},"default_branch":"main","open_pr_counter":1}]"#
                case "/api/v1/notifications":
                    body = #"[{"id":7,"unread":true,"updated_at":"2026-11-14T10:00:00Z","repository":{"full_name":"Alex/Web-Deploy"},"subject":{"title":"Build alert","type":"Pull","url":"https://git.example/pulls/12"}}]"#
                case "/api/v1/repos/Alex/Web-Deploy/actions/tasks":
                    body = #"{"workflow_runs":[{"id":184,"display_title":"Deploy","head_branch":"main","head_sha":"abc123456","status":"failure","run_number":184,"workflow_id":"deploy.yml"}]}"#
                case "/api/v1/repos/Alex/Web-Deploy/actions/secrets":
                    body = #"[{"name":"DEPLOY_KEY","created_at":"2026-11-14T00:00:00Z"}]"#
                case "/api/v1/repos/Alex/Web-Deploy/actions/variables":
                    body = #"[{"name":"ENV","data":"prod"}]"#
                case "/api/v1/repos/Alex/Web-Deploy/pulls":
                    body = #"[{"id":12,"number":12,"title":"Release fix","state":"open","mergeable":true,"additions":4,"deletions":1,"user":{"login":"Alex"},"head":{"ref":"fix","sha":"abc1234"},"base":{"ref":"main"}}]"#
                case "/api/v1/repos/Alex/Web-Deploy/issues/12/comments":
                    body = #"[{"id":1,"body":"Ship it","created_at":"2026-11-14T10:00:00Z","user":{"login":"alice"}}]"#
                case "/api/v1/repos/Alex/Web-Deploy/commits/abc1234/status":
                    body = #"{"statuses":[{"id":2,"context":"ci/build","status":"success"}]}"#
                case "/api/v1/admin/cron":
                    body = #"[{"name":"gc","schedule":"@hourly","next":"2026-11-15","prev":"2026-11-14","exec_times":2}]"#
                case "/api/v1/admin/users":
                    body = #"[{"id":1,"login":"Alex","email":"a@example.com","is_admin":true,"restricted":false,"prohibit_login":false}]"#
                case "/api/v1/repos/Alex/Web-Deploy/contents":
                    body = #"[{"name":"README.md","path":"README.md","type":"file","size":12}]"#
                case "/api/v1/repos/Alex/Web-Deploy/contents/README.md":
                    body = #"{"content":"IyBXZWIK"}"#
                default:
                    body = "[]"
                }
                return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
            }
        }

        let defaults = UserDefaults(suiteName: "teapulse.test.\(UUID().uuidString)")!
        let store = AppStore(
            credentialStore: InMemoryCredentialStore(),
            transport: RichTransport(),
            forceDemoMode: true,
            defaults: defaults,
            writesWidgetSnapshot: false
        )
        let ok = await store.connectLiveInstance(
            displayName: "Prod", publicURL: "https://git.example.com", lanURL: nil, patToken: "pat", sshPortOverride: nil, barkURL: nil
        )
        #expect(ok)
        #expect(store.notifications.count == 1)
        #expect(store.runs.first?.runNumber == 184)
        #expect(store.cronTasks.count == 1)
        #expect(store.adminStats.totalUsers == 1)
        #expect(store.adminStats.totalRepos == 1)

        await store.loadRepositoryDetails(repoFullName: "alex/web-deploy")
        #expect(store.secretsByRepo["Alex/Web-Deploy"]?.first?.name == "DEPLOY_KEY")
        #expect(store.variablesByRepo["Alex/Web-Deploy"]?.first?.value == "prod")
        let pr = store.pullRequests.first(where: { $0.number == 12 })
        #expect(pr?.comments.first?.body == "Ship it")
        #expect(pr?.checks.first?.name == "ci/build")

        store.runs = []
        store.handle(deepLinkString: "teapulse://actions/alex/web-deploy/184?step=failed")
        for _ in 0..<20 where store.selectedRun?.runNumber != 184 {
            try? await Task.sleep(for: .milliseconds(25))
        }
        #expect(store.selectedSection == .actions)
        #expect(store.selectedRun?.runNumber == 184)
    }

    @Test("Loading state flags transition across live workspace, repository details, and PR details")
    func loadingStateTransitionsForLiveWorkspaceRepoAndPR() async {
        struct SparseTransport: HTTPTransport {
            func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData {
                let path = request.url?.path ?? ""
                let body: String
                switch path {
                case "/api/healthz", "/api/v1/version": body = #"{"version":"1.27.3"}"#
                case "/api/v1/user": body = #"{"login":"alex"}"#
                case "/api/v1/user/repos":
                    body = #"[{"id":7,"name":"app","full_name":"alex/app","private":false,"mirror":false,"default_branch":"main","open_pr_counter":1,"owner":{"login":"alex","type":"User"}}]"#
                case "/api/v1/repos/alex/app/pulls":
                    body = #"[{"id":70,"number":7,"title":"Fix loading","state":"open","mergeable":true,"additions":4,"deletions":1,"user":{"login":"alex"},"head":{"ref":"feat/ui","sha":"abc"},"base":{"ref":"main"}}]"#
                case "/api/v1/repos/alex/app/issues/7/comments":
                    body = #"[{"id":1,"body":"LGTM","created_at":"2026-11-15T10:00:00Z","user":{"login":"reviewer"}}]"#
                case "/api/v1/repos/alex/app/contents":
                    body = #"[{"name":"README.md","path":"README.md","type":"file","size":8}]"#
                default:
                    body = "[]"
                }
                return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
            }
        }

        let defaults = UserDefaults(suiteName: "teapulse.loading.\(UUID().uuidString)")!
        let credentials = InMemoryCredentialStore()
        let seedStore = AppStore(credentialStore: credentials, transport: SparseTransport(), forceDemoMode: true, defaults: defaults, writesWidgetSnapshot: false)
        #expect(seedStore.isInitialWorkspaceLoading == false)
        let ok = await seedStore.connectLiveInstance(
            displayName: "Prod", publicURL: "https://git.example.com", lanURL: nil, patToken: "pat", sshPortOverride: nil, barkURL: nil
        )
        #expect(ok)
        #expect(seedStore.isInitialWorkspaceLoading == false)

        let relaunched = AppStore(credentialStore: credentials, transport: SparseTransport(), defaults: defaults, writesWidgetSnapshot: false)
        #expect(relaunched.isInitialWorkspaceLoading == true)
        #expect(relaunched.isLoadingRepoDetails("alex/app") == true)

        await relaunched.refreshLiveInstanceData()
        #expect(relaunched.isInitialWorkspaceLoading == false)
        #expect(relaunched.isLoadingRepoDetails("alex/app") == true)

        let unenrichedPR = PullRequestDetail(
            id: "pr-unloaded", number: 7, repoFullName: "alex/app", title: "Fix loading",
            author: "alex", headBranch: "feat/ui", baseBranch: "main", state: .open, mergeable: true, additions: 4, deletions: 1
        )
        relaunched.pullRequests = [unenrichedPR]
        #expect(relaunched.isLoadingPRDetails(unenrichedPR) == true)

        await relaunched.loadPullRequestDetails(unenrichedPR)
        #expect(relaunched.isLoadingPRDetails(relaunched.pullRequests[0]) == false)
        #expect(relaunched.pullRequests[0].comments.first?.body == "LGTM")

        await relaunched.loadRepositoryDetails(repoFullName: "alex/app")
        #expect(relaunched.isLoadingRepoDetails("alex/app") == false)
    }

    @Test("Filters repositories by specific organization across scopes, mirrors, and org display names")
    func filtersRepositoriesBySpecificOrganization() async {
        let store = AppStore(
            credentialStore: InMemoryCredentialStore(),
            forceDemoMode: true,
            defaults: UserDefaults(suiteName: "teapulse.orgfilter.demo.\(UUID().uuidString)")!,
            writesWidgetSnapshot: false
        )

        #expect(store.availableOrganizations.map(\.username) == ["mirror", "ops"])
        #expect(store.allOrganizationsRepoCount == 2)
        #expect(store.repositoryCount(forOrganization: "ops") == 1)
        #expect(store.repositoryCount(forOrganization: "mirror") == 1)

        store.selectRepoScope(.org)
        #expect(store.filteredRepositories.map(\.fullName) == ["ops/nginx-gateway", "mirror/swift-argument-parser"])

        store.toggleOrganizationFilter("Mirror")
        #expect(store.isOrganizationSelected("mirror"))
        #expect(store.filteredRepositories.map(\.fullName) == ["mirror/swift-argument-parser"])

        store.toggleOrganizationFilter("mirror")
        #expect(store.selectedOrganizationFilter == nil)
        #expect(store.filteredRepositories.count == 2)

        store.selectRepoScope(.personal)
        #expect(store.filteredRepositories.map(\.fullName) == ["alex/teapulse-core", "alex/web-deploy"])

        store.toggleOrganizationFilter("ops")
        #expect(store.repoScopeFilter == .org)
        #expect(store.filteredRepositories.map(\.fullName) == ["ops/nginx-gateway"])

        store.clearOrganizationFilter()
        #expect(store.repoScopeFilter == .org)
        #expect(store.selectedOrganizationFilter == nil)
        #expect(store.filteredRepositories.count == 2)

        store.selectRepoScope(.all)
        store.repoSearchQuery = "基础设施"
        #expect(store.filteredRepositories.map(\.fullName) == ["ops/nginx-gateway"])

        struct OrgTransport: HTTPTransport {
            func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData {
                let path = request.url?.path ?? ""
                let body: String
                switch path {
                case "/api/healthz", "/api/v1/version": body = #"{"version":"1.27.3"}"#
                case "/api/v1/user": body = #"{"login":"alex"}"#
                case "/api/v1/user/orgs":
                    body = #"[{"id":5,"username":"platform","full_name":"核心平台"},{"id":6,"username":"upstream","full_name":"第三方镜像"}]"#
                case "/api/v1/user/repos":
                    body = #"[{"id":1,"name":"notes","full_name":"alex/notes","owner":{"login":"alex","type":"User"},"mirror":false,"updated_at":"2026-11-16T01:00:00Z"}]"#
                case "/api/v1/orgs/platform/repos":
                    body = #"[{"id":2,"name":"api","full_name":"platform/api","owner":{"login":"platform","type":"Organization"},"mirror":false,"updated_at":"2026-11-16T02:00:00Z"},{"id":3,"name":"web","full_name":"platform/web","owner":{"login":"platform","type":"Organization"},"mirror":false,"updated_at":"2026-11-15T02:00:00Z"}]"#
                case "/api/v1/orgs/upstream/repos":
                    body = #"[{"id":4,"name":"nio","full_name":"upstream/nio","owner":{"login":"upstream","type":"Organization"},"mirror":true,"updated_at":"2026-11-16T03:00:00Z"}]"#
                default:
                    body = "[]"
                }
                return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
            }
        }

        let liveStore = AppStore(
            credentialStore: InMemoryCredentialStore(),
            transport: OrgTransport(),
            forceDemoMode: true,
            defaults: UserDefaults(suiteName: "teapulse.orgfilter.live.\(UUID().uuidString)")!,
            writesWidgetSnapshot: false
        )
        let ok = await liveStore.connectLiveInstance(
            displayName: "Prod", publicURL: "https://git.example.com", lanURL: nil, patToken: "pat", sshPortOverride: nil, barkURL: nil
        )
        #expect(ok)
        #expect(liveStore.availableOrganizations.map(\.username) == ["platform", "upstream"])
        #expect(liveStore.allOrganizationsRepoCount == 3)
        #expect(liveStore.repositoryCount(forOrganization: "platform") == 2)
        #expect(liveStore.repositoryCount(forOrganization: "upstream") == 1)

        liveStore.selectRepoScope(.mirror)
        #expect(liveStore.repositoryCount(forOrganization: "platform") == 0)
        #expect(liveStore.repositoryCount(forOrganization: "upstream") == 1)

        liveStore.toggleOrganizationFilter("platform")
        #expect(liveStore.filteredRepositories.isEmpty)

        liveStore.selectRepoScope(.org)
        #expect(liveStore.isOrganizationSelected("platform"))
        #expect(liveStore.filteredRepositories.map(\.fullName) == ["platform/api", "platform/web"])

        liveStore.clearOrganizationFilter()
        liveStore.repoSearchQuery = "核心平台"
        #expect(liveStore.filteredRepositories.map(\.fullName) == ["platform/api", "platform/web"])
    }
}
