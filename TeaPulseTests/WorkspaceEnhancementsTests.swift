import Foundation
import Testing
@testable import TeaPulse
@testable import GiteaKit

@MainActor
@Suite("WorkspaceEnhancementsTests")
struct WorkspaceEnhancementsTests {
    @Test("Infers ToastTone across success, warning, and error messages")
    func infersToastTones() {
        #expect(ToastTone.infer(from: "已复制反代 HTTPS") == .success)
        #expect(ToastTone.infer(from: "未找到目标构建：ops/app #1") == .warning)
        #expect(ToastTone.infer(from: "删除密钥失败：HTTP 403") == .error)
        #expect(ToastTone.infer(from: "地址格式无效，请检查协议与端口") == .error)

        let store = AppStore(
            credentialStore: InMemoryCredentialStore(),
            forceDemoMode: true,
            defaults: UserDefaults(suiteName: "teapulse.toast.\(UUID().uuidString)")!,
            writesWidgetSnapshot: false
        )
        store.showToast("HTTP 403 Forbidden")
        #expect(store.statusToastTone == .error)
        store.showToast("自定义提示", tone: .warning)
        #expect(store.statusToastTone == .warning)
    }

    @Test("Aggregates open PRs across repos, merges stars/runners/triage, persists custom pins, and loads branch/commit/logs")
    func liveWorkspaceEnhancementsEndToEnd() async {
        let logPayload = """
        ::group::Run Tests
        \u{001B}[31merror: unit test failed\u{001B}[0m
        ::endgroup::
        """
        let diffPayload = """
        diff --git a/README.md b/README.md
        --- a/README.md
        +++ b/README.md
        @@ -1 +1,2 @@
         # App
        +Updated
        """

        struct FullEnhancementTransport: HTTPTransport {
            let logText: String
            let diffText: String
            func perform(_ request: URLRequest, timeout: TimeInterval) async throws -> HTTPResponseData {
                let path = request.url?.path ?? ""
                let method = request.httpMethod ?? "GET"
                let query = request.url?.query ?? ""
                switch (method, path) {
                case ("GET", "/api/healthz"), ("GET", "/api/v1/version"):
                    return HTTPResponseData(statusCode: 200, body: Data(#"{"version":"1.27.3"}"#.utf8))
                case ("GET", "/api/v1/user"):
                    return HTTPResponseData(statusCode: 200, body: Data(#"{"login":"alex"}"#.utf8))
                case ("GET", "/api/v1/user/orgs"):
                    return HTTPResponseData(statusCode: 200, body: Data(#"[{"id":2,"username":"ops","full_name":"运维"}]"#.utf8))
                case ("GET", "/api/v1/user/repos"):
                    let body = """
                    [
                      {"id":1,"name":"first-empty","full_name":"alex/first-empty","owner":{"login":"alex","type":"User"},"open_pr_counter":0,"mirror":false,"updated_at":"2026-11-16T09:00:00Z"},
                      {"id":2,"name":"backend","full_name":"ops/backend","owner":{"login":"ops","type":"Organization"},"open_pr_counter":1,"mirror":false,"updated_at":"2026-11-16T08:00:00Z"}
                    ]
                    """
                    return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
                case ("GET", "/api/v1/orgs/ops/repos"):
                    let body = #"[{"id":2,"name":"backend","full_name":"ops/backend","owner":{"login":"ops","type":"Organization"},"open_pr_counter":1,"mirror":false,"updated_at":"2026-11-16T08:00:00Z"}]"#
                    return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
                case ("GET", "/api/v1/user/starred"):
                    let body = #"[{"id":2,"name":"backend","full_name":"ops/backend","owner":{"login":"ops","type":"Organization"},"open_pr_counter":1,"mirror":false,"stars_count":5,"updated_at":"2026-11-16T08:00:00Z"},{"id":3,"name":"external-star","full_name":"community/external-star","owner":{"login":"community","type":"User"},"open_pr_counter":0,"mirror":false,"stars_count":12,"updated_at":"2026-11-14T08:00:00Z"}]"#
                    return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
                case ("GET", "/api/v1/repos/ops/backend/pulls"):
                    let body = #"[{"id":99,"number":99,"title":"Multi-repo PR","state":"open","mergeable":true,"additions":6,"deletions":2,"user":{"login":"alex"},"head":{"ref":"feat/api","sha":"abc"},"base":{"ref":"main"}}]"#
                    return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
                case ("GET", "/api/v1/repos/ops/backend/actions/tasks"):
                    let body = #"{"workflow_runs":[{"id":700,"display_title":"Backend CI","head_branch":"main","head_sha":"deadbee","status":"failure","run_number":70,"workflow_id":"ci.yml"}]}"#
                    return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
                case ("GET", "/api/v1/admin/actions/runners"):
                    let body = #"{"runners":[{"id":8,"name":"runner-gz-01","status":"online","busy":false,"version":"0.2.11","labels":["linux"]}]}"#
                    return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
                case ("PUT", "/api/v1/user/starred/alex/first-empty"),
                     ("DELETE", "/api/v1/user/starred/alex/first-empty"):
                    return HTTPResponseData(statusCode: 204, body: Data())
                case ("GET", "/api/v1/repos/ops/backend/branches"):
                    let body = #"[{"name":"main","commit":{"id":"1111111"}},{"name":"release/v2","commit":{"id":"2222222"}}]"#
                    return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
                case ("GET", "/api/v1/repos/ops/backend/commits"):
                    let sha = query.contains("release") ? "c222" : "c111"
                    let title = query.contains("release") ? "release branch commit" : "main branch commit"
                    let body = #"[{"sha":"\#(sha)","commit":{"message":"\#(title)","author":{"name":"alex","date":"2026-11-16T08:00:00Z"}},"author":{"login":"alex"}}]"#
                    return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
                case ("GET", "/api/v1/repos/ops/backend/contents"):
                    let marker = query.contains("release") ? "CHANGELOG.md" : "README.md"
                    let body = #"[{"name":"\#(marker)","path":"\#(marker)","sha":"s1","type":"file","size":10}]"#
                    return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
                case ("GET", "/api/v1/repos/ops/backend/git/commits/c111.diff"):
                    return HTTPResponseData(statusCode: 200, body: Data(diffText.utf8))
                case ("GET", "/api/v1/repos/ops/backend/actions/jobs/700"):
                    let body = #"{"runner_name":"runner-gz-01","started_at":"2026-11-16T08:00:00Z","completed_at":"2026-11-16T08:00:40Z","steps":[]}"#
                    return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
                case ("GET", "/api/v1/repos/ops/backend/actions/jobs/700/logs"):
                    return HTTPResponseData(statusCode: 200, body: Data(logText.utf8))
                default:
                    return HTTPResponseData(statusCode: 200, body: Data("[]".utf8))
                }
            }
        }

        let suiteName = "teapulse.enhance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let credentials = InMemoryCredentialStore()
        let transport = FullEnhancementTransport(logText: logPayload, diffText: diffPayload)

        let store = AppStore(
            credentialStore: credentials,
            transport: transport,
            forceDemoMode: true,
            defaults: defaults,
            writesWidgetSnapshot: false
        )
        let ok = await store.connectLiveInstance(
            displayName: "Prod", publicURL: "https://git.example.com", lanURL: nil, patToken: "pat", sshPortOverride: nil, barkURL: nil
        )
        #expect(ok)

        // Multi-repo PRs, failed run in triage, starred merge, runners & pinned CI status
        #expect(store.pullRequests.contains { $0.repoFullName == "ops/backend" && $0.number == 99 })
        #expect(store.triage.contains { $0.kind == .pullRequest && $0.repoFullName == "ops/backend" })
        #expect(store.triage.contains { $0.kind == .failedRun && $0.repoFullName == "ops/backend" })
        #expect(store.repositories.first { $0.fullName == "ops/backend" }?.isStarred == true)
        #expect(store.repositories.contains { $0.fullName == "community/external-star" && $0.isStarred })
        #expect(store.runners.map(\.name) == ["runner-gz-01"])
        #expect(store.adminStats.activeRunners == 1)
        #expect(store.pinnedRepos.first { $0.fullName == "ops/backend" }?.ciStatus == .failure)

        // Star toggle
        let firstEmptyID = store.repositories.first { $0.fullName == "alex/first-empty" }!.id
        #expect(await store.toggleStarRepository(repoID: firstEmptyID) == true)
        #expect(store.repositories.first { $0.id == firstEmptyID }?.isStarred == true)

        // Custom pin persistence & empty unpin support
        for existing in store.pinnedRepos {
            store.togglePinRepository(existing.fullName)
        }
        #expect(store.pinnedRepos.isEmpty)
        store.togglePinRepository("ops/backend")
        #expect(store.pinnedRepos.map(\.fullName) == ["ops/backend"])

        let relaunched = AppStore(
            credentialStore: credentials,
            transport: transport,
            defaults: defaults,
            writesWidgetSnapshot: false
        )
        await relaunched.refreshLiveInstanceData()
        #expect(relaunched.pinnedRepos.map(\.fullName) == ["ops/backend"])

        // Branch switch reloads commits & files, commit diff loads and caches
        await store.loadRepositoryDetails(repoFullName: "ops/backend")
        #expect(store.commitsByRepo["ops/backend"]?.first?.title == "main branch commit")
        let commitDiff = await store.loadCommitDiff(repoFullName: "ops/backend", sha: "c111")
        #expect(commitDiff.count == 1)
        #expect(commitDiff.first?.additions == 1)

        await store.selectRepositoryBranch(repoFullName: "ops/backend", branch: "release/v2")
        #expect(store.commitsByRepo["ops/backend"]?.first?.title == "release branch commit")
        #expect(store.repoFiles["ops/backend"]?.first?.name == "CHANGELOG.md")

        // On-demand workflow job steps & ANSI logs
        let targetRun = store.runs.first { $0.jobID == 700 }!
        await store.loadWorkflowRunLogs(for: targetRun)
        let updatedRun = store.runs.first { $0.jobID == 700 }!
        #expect(updatedRun.durationSeconds == 40)
        #expect(updatedRun.steps.first?.name == "Run Tests")
        #expect(updatedRun.steps.first?.firstErrorLineIndex == 0)

        // Secret & Variable live CRUD
        #expect(await store.upsertSecret(repoFullName: "ops/backend", name: "deploy_token", value: "sec-val"))
        if let secID = store.secretsByRepo["ops/backend"]?.first(where: { $0.name == "DEPLOY_TOKEN" })?.id {
            #expect(await store.deleteSecret(repoFullName: "ops/backend", id: secID))
            #expect(store.secretsByRepo["ops/backend"]?.isEmpty == true)
        }
        #expect(await store.upsertVariable(repoFullName: "ops/backend", name: "app_env", value: "staging"))
        #expect(await store.upsertVariable(repoFullName: "ops/backend", name: "app_env", value: "prod"))
        if let varItem = store.variablesByRepo["ops/backend"]?.first(where: { $0.name == "APP_ENV" }) {
            #expect(varItem.value == "prod")
            #expect(await store.deleteVariable(repoFullName: "ops/backend", id: varItem.id))
            #expect(store.variablesByRepo["ops/backend"]?.isEmpty == true)
        }
    }
}
