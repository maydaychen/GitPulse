import Foundation
import Testing
@testable import GiteaKit

@Suite("GiteaClientEnhancementsTests")
struct GiteaClientEnhancementsTests {
    @Test("Formats file sizes in B, KB, and MB")
    func formatsFileSizes() {
        let tiny = RepoFileEntry(id: "1", name: "a.txt", path: "a.txt", isDirectory: false, sizeBytes: 512, sha: "1")
        let kb = RepoFileEntry(id: "2", name: "b.txt", path: "b.txt", isDirectory: false, sizeBytes: 2048, sha: "2")
        let mb = RepoFileEntry(id: "3", name: "c.bin", path: "c.bin", isDirectory: false, sizeBytes: 2_621_440, sha: "3")
        #expect(tiny.formattedSize == "512 B")
        #expect(kb.formattedSize == "2.0 KB")
        #expect(mb.formattedSize == "2.5 MB")
    }

    @Test("Fetches starred repos, updates star status, fetches branches, commits, and commit diff")
    func starredBranchesCommitsAndDiff() async throws {
        let diffText = """
        diff --git a/Sources/App.swift b/Sources/App.swift
        --- a/Sources/App.swift
        +++ b/Sources/App.swift
        @@ -1,2 +1,3 @@
         import Foundation
        +print("hi")
        """
        let transport = MockHTTPTransport { request, _ in
            let path = request.url?.path ?? ""
            let method = request.httpMethod ?? "GET"
            switch (method, path) {
            case ("GET", "/api/v1/user/starred"):
                let body = #"[{"id":77,"name":"tools","full_name":"ops/tools","owner":{"login":"ops","type":"Organization"},"mirror":false}]"#
                return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
            case ("PUT", "/api/v1/user/starred/ops/tools"),
                 ("DELETE", "/api/v1/user/starred/ops/tools"):
                return HTTPResponseData(statusCode: 204, body: Data())
            case ("GET", "/api/v1/repos/ops/tools/branches"):
                let body = #"[{"name":"dev","commit":{"id":"1111111aaaa"}},{"name":"main","commit":{"id":"2222222bbbb"}}]"#
                return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
            case ("GET", "/api/v1/repos/ops/tools/tags"):
                let body = #"[{"name":"v1.0.0","commit":{"sha":"2222222bbbb"}}]"#
                return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
            case ("GET", "/api/v1/repos/ops/tools/commits"):
                let body = #"[{"sha":"2222222bbbb","commit":{"message":"feat: add health probe\n\ndetails","author":{"name":"Alex","date":"2026-11-16T10:00:00Z"}},"author":{"login":"alex"},"files":[{"filename":"Sources/App.swift"}]}]"#
                return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
            case ("GET", "/api/v1/repos/ops/tools/git/commits/2222222bbbb.diff"):
                return HTTPResponseData(statusCode: 200, body: Data(diffText.utf8))
            default:
                return HTTPResponseData(statusCode: 404, body: Data())
            }
        }
        let client = GiteaClient(
            baseURL: "https://git.teapulse.example:8443",
            credentials: StoredCredentials(patToken: "pat"),
            transport: transport
        )

        let starred = try await client.fetchStarredRepositories(currentUsername: "alex")
        #expect(starred.count == 1)
        #expect(starred[0].isStarred == true)

        try await client.setRepositoryStarred(owner: "ops", repo: "tools", starred: true)
        try await client.setRepositoryStarred(owner: "ops", repo: "tools", starred: false)

        let branches = try await client.fetchRepoBranches(owner: "ops", repo: "tools", defaultBranch: "main")
        #expect(branches.map(\.name) == ["main", "dev", "v1.0.0"])
        #expect(branches[0].isDefault == true)
        #expect(branches[2].isTag == true)

        let commits = try await client.fetchRepoCommits(owner: "ops", repo: "tools", sha: "main")
        #expect(commits.count == 1)
        #expect(commits[0].shortSHA == "2222222")
        #expect(commits[0].title == "feat: add health probe")
        #expect(commits[0].filesChangedCount == 1)

        let diff = try await client.fetchCommitDiff(owner: "ops", repo: "tools", sha: "2222222bbbb")
        #expect(diff.count == 1)
        #expect(diff[0].additions == 1)
    }

    @Test("Fetches job ANSI steps/logs, handles structured fallback, secrets/variables CRUD, and runners")
    func actionsLogsVariablesSecretsAndRunners() async throws {
        let ansiLog = """
        ::group::Build & Test
        Compiling targets...
        \u{001B}[31merror: test assertion failed\u{001B}[0m
        ::endgroup::
        """
        let transport = MockHTTPTransport { request, _ in
            let path = request.url?.path ?? ""
            let method = request.httpMethod ?? "GET"
            switch (method, path) {
            case ("GET", "/api/v1/repos/ops/app/actions/jobs/501"):
                let body = #"{"runner_name":"node-hz-01","started_at":"2026-11-16T08:00:00Z","completed_at":"2026-11-16T08:01:15Z","steps":[]}"#
                return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
            case ("GET", "/api/v1/repos/ops/app/actions/jobs/501/logs"):
                return HTTPResponseData(statusCode: 200, body: Data(ansiLog.utf8))
            case ("GET", "/api/v1/repos/ops/app/actions/jobs/502"):
                let body = #"{"runner_name":"node-sh-02","started_at":"2026-11-16T08:00:00Z","completed_at":"2026-11-16T08:00:30Z","steps":[{"name":"Checkout","status":"success","number":1}]}"#
                return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
            case ("GET", "/api/v1/repos/ops/app/actions/jobs/502/logs"):
                return HTTPResponseData(statusCode: 404, body: Data())
            case ("DELETE", "/api/v1/repos/ops/app/actions/secrets/OLD_KEY"):
                return HTTPResponseData(statusCode: 204, body: Data())
            case ("POST", "/api/v1/repos/ops/app/actions/variables/ENV"),
                 ("PUT", "/api/v1/repos/ops/app/actions/variables/ENV"),
                 ("DELETE", "/api/v1/repos/ops/app/actions/variables/ENV"):
                return HTTPResponseData(statusCode: 204, body: Data())
            case ("GET", "/api/v1/admin/actions/runners"):
                return HTTPResponseData(statusCode: 403, body: Data())
            case ("GET", "/api/v1/user/actions/runners"):
                let body = #"{"runners":[{"id":1,"name":"linux-arm64","status":"online","busy":true,"version":"0.2.11","labels":["ubuntu-latest","docker"]}]}"#
                return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
            case ("GET", "/api/v1/orgs/ops/actions/runners"):
                let body = #"[{"id":2,"name":"macos-builder","status":"offline","busy":false,"ephemeral":true,"labels":[{"name":"macos-15"}]}]"#
                return HTTPResponseData(statusCode: 200, body: Data(body.utf8))
            default:
                return HTTPResponseData(statusCode: 404, body: Data())
            }
        }
        let client = GiteaClient(
            baseURL: "https://git.teapulse.example:8443",
            credentials: StoredCredentials(patToken: "pat"),
            transport: transport
        )

        let jobWithLog = await client.fetchActionJobStepsAndLogs(owner: "ops", repo: "app", jobID: 501, fallbackStatus: .failure)
        #expect(jobWithLog.runnerName == "node-hz-01")
        #expect(jobWithLog.durationSeconds == 75)
        #expect(jobWithLog.steps.first?.name == "Build & Test")
        #expect(jobWithLog.steps.first?.firstErrorLineIndex == 1)

        let jobStructured = await client.fetchActionJobStepsAndLogs(owner: "ops", repo: "app", jobID: 502, fallbackStatus: .success)
        #expect(jobStructured.runnerName == "node-sh-02")
        #expect(jobStructured.durationSeconds == 30)
        #expect(jobStructured.steps.first?.name == "Checkout")

        try await client.deleteActionSecret(owner: "ops", repo: "app", name: "OLD_KEY")
        try await client.upsertActionVariable(owner: "ops", repo: "app", name: "ENV", value: "staging", exists: false)
        try await client.upsertActionVariable(owner: "ops", repo: "app", name: "ENV", value: "prod", exists: true)
        try await client.deleteActionVariable(owner: "ops", repo: "app", name: "ENV")

        let reqs = transport.snapshotRequests()
        let varCreateReq = reqs.first { $0.method == "POST" && $0.url.path.hasSuffix("/actions/variables/ENV") }
        let varUpdateReq = reqs.first { $0.method == "PUT" && $0.url.path.hasSuffix("/actions/variables/ENV") }
        #expect(varCreateReq != nil)
        #expect(varUpdateReq != nil)
        if let body = varUpdateReq?.body, let json = String(data: body, encoding: .utf8) {
            #expect(json.contains("\"value\":\"prod\""))
        } else {
            Issue.record("Expected JSON value payload on variable PUT")
        }

        let runners = await client.fetchAvailableRunners(
            organizations: [OrganizationSummary(id: "org-1", username: "ops")],
            repositories: []
        )
        #expect(runners.count == 2)
        #expect(runners[0].status == .busy)
        #expect(runners[0].labels == ["ubuntu-latest", "docker"])
        #expect(runners[1].status == .offline)
        #expect(runners[1].labels == ["macos-15"])
    }
}
