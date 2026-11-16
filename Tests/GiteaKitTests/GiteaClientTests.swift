import Foundation
import Testing
@testable import GiteaKit

@Suite("GiteaClientTests")
struct GiteaClientTests {
    @Test("Review comments preserve old and new diff positions")
    func reviewCommentSides() async throws {
        let transport = MockHTTPTransport { _, _ in HTTPResponseData(statusCode: 200, body: Data()) }
        let client = GiteaClient(baseURL: "https://git.example.com", credentials: StoredCredentials(patToken: "synthetic-pat"), transport: transport)
        try await client.submitPullReview(owner: "tester", repo: "sample", index: 42, decision: .comment, body: "Review", comments: [
            InlineReviewDraft(filePath: "App.swift", lineNumber: 10, side: .old, body: "Deleted line"),
            InlineReviewDraft(filePath: "App.swift", lineNumber: 20, side: .new, body: "Added line")
        ])
        let body = try #require(transport.snapshotRequests().first?.body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let comments = try #require(json["comments"] as? [[String: Any]])
        #expect(comments.count == 2)
        #expect(comments[0]["old_position"] as? Int == 10)
        #expect(comments[0]["new_position"] as? Int == 0)
        #expect(comments[1]["old_position"] as? Int == 0)
        #expect(comments[1]["new_position"] as? Int == 20)
    }

    @Test("Runner registration uses the Actions admin endpoint")
    func runnerRegistrationEndpoint() async throws {
        let transport = MockHTTPTransport { request, _ in
            let matches = request.url?.path == "/api/v1/admin/actions/runners/registration-token" && request.httpMethod == "POST"
            return HTTPResponseData(statusCode: matches ? 200 : 404, body: Data(#"{"token":"synthetic-registration-token"}"#.utf8))
        }
        let client = GiteaClient(baseURL: "https://git.example.com", credentials: StoredCredentials(patToken: "synthetic-pat"), transport: transport)
        #expect(try await client.createRunnerRegistrationToken() == "synthetic-registration-token")
    }

    @Test("Repository metadata does not invent star, mirror or README state")
    func preservesUnknownMetadata() async throws {
        let transport = MockHTTPTransport { _, _ in
            HTTPResponseData(statusCode: 200, body: Data(#"[{"id":1,"name":"sample","full_name":"tester/sample","owner":{"login":"tester"},"stars_count":10,"mirror":true}]"#.utf8))
        }
        let client = GiteaClient(baseURL: "https://git.example.com", credentials: StoredCredentials(patToken: "synthetic-test-pat"), transport: transport)
        let repos = try await client.fetchRepositories()
        #expect(repos.first?.isStarred == false)
        #expect(repos.first?.lastMirrorSyncText == nil)
        #expect(repos.first?.readmeMarkdown == "README 暂未加载")
    }

    @Test("Sends Authorization token header and preserves custom proxy headers and port")
    func injectsPATAndCustomHeaders() async throws {
        let transport = MockHTTPTransport { _, _ in
            HTTPResponseData(statusCode: 200, body: Data(#"{"version":"1.27.3"}"#.utf8))
        }
        let client = GiteaClient(
            baseURL: "https://git.teapulse.example:8443",
            credentials: StoredCredentials(patToken: "secret-pat-test", customHeaders: ["X-Proxy-Gate": "ok"]),
            transport: transport
        )

        let version = try await client.fetchVersion()
        #expect(version == "1.27.3")

        let requests = transport.snapshotRequests()
        #expect(requests.count == 1)
        #expect(requests[0].url.absoluteString == "https://git.teapulse.example:8443/api/v1/version")
        #expect(requests[0].headers["Authorization"] == "token secret-pat-test")
        #expect(requests[0].headers["X-Proxy-Gate"] == "ok")
    }

    @Test("Surfaces explicit HTTP 413 client_max_body_size error on release upload")
    func surfacesNginx413() async {
        let transport = MockHTTPTransport { _, _ in
            HTTPResponseData(statusCode: 413, body: Data("Request Entity Too Large".utf8))
        }
        let client = GiteaClient(
            baseURL: "https://git.teapulse.example:8443",
            credentials: StoredCredentials(patToken: "pat"),
            transport: transport
        )

        await #expect(throws: GiteaClientError.self) {
            try await client.uploadReleaseAsset(
                owner: "alex",
                repo: "teapulse-core",
                releaseID: 1,
                fileName: "bundle.zip",
                data: Data([0x01, 0x02])
            )
        }
    }

    @Test("Sends Range header for incremental action job log polling")
    func sendsRangeHeaderForLogs() async throws {
        let transport = MockHTTPTransport { _, _ in
            HTTPResponseData(statusCode: 206, body: Data("next line".utf8))
        }
        let client = GiteaClient(
            baseURL: "https://git.teapulse.example:8443",
            credentials: StoredCredentials(patToken: "pat"),
            transport: transport
        )

        let chunk = try await client.fetchJobLogChunk(owner: "alex", repo: "web-deploy", jobID: 9184, byteOffset: 256)
        #expect(chunk == "next line")
        #expect(transport.snapshotRequests().first?.headers["Range"] == "bytes=256-")
    }

    @Test("Classifies organization and third-party owned repositories as .org")
    func classifiesOrganizationRepos() async throws {
        let payload = """
        [
          {"id":1,"name":"infra","full_name":"ops-team/infra","owner":{"login":"ops-team","type":"Organization"},"mirror":false},
          {"id":2,"name":"shared","full_name":"alice/shared","owner":{"login":"alice","type":"User"},"mirror":false},
          {"id":3,"name":"notes","full_name":"alex/notes","owner":{"login":"alex","type":"User"},"mirror":false},
          {"id":4,"name":"upstream","full_name":"ops-team/upstream","owner":{"login":"ops-team","type":"Organization"},"mirror":true}
        ]
        """
        let transport = MockHTTPTransport { _, _ in
            HTTPResponseData(statusCode: 200, body: Data(payload.utf8))
        }
        let client = GiteaClient(
            baseURL: "https://git.teapulse.example:8443",
            credentials: StoredCredentials(patToken: "pat"),
            transport: transport
        )
        let repos = try await client.fetchRepositories(currentUsername: "alex")
        #expect(repos.count == 4)
        #expect(repos[0].scope == .org)
        #expect(repos[0].isOrganizationOwned == true)
        #expect(repos[1].scope == .org)
        #expect(repos[1].isOrganizationOwned == true)
        #expect(repos[2].scope == .personal)
        #expect(repos[2].isOrganizationOwned == false)
        #expect(repos[3].scope == .mirror)
        #expect(repos[3].isOrganizationOwned == true)
    }

    @Test("Fetches repository contents, base64 file content, and open issues")
    func fetchesRepositoryDetailsAndDecodesBase64() async throws {
        let readmeBase64 = Data("# engineering-wiki\nHello\n".utf8).base64EncodedString()
        let transport = MockHTTPTransport { request, _ in
            let path = request.url?.path ?? ""
            if path == "/api/v1/repos/octo/engineering-wiki/contents" {
                let json = """
                [
                  {"name":"README.md","path":"README.md","sha":"a1","type":"file","size":14},
                  {"name":"docs","path":"docs","sha":"d1","type":"dir","size":0}
                ]
                """
                return HTTPResponseData(statusCode: 200, body: Data(json.utf8))
            }
            if path == "/api/v1/repos/octo/engineering-wiki/contents/docs%2Fguide.md" ||
               path == "/api/v1/repos/octo/engineering-wiki/contents/docs/guide.md" {
                let json = "{\"name\":\"guide.md\",\"path\":\"docs/guide.md\",\"sha\":\"b2\",\"type\":\"file\",\"size\":14,\"encoding\":\"base64\",\"content\":\"\(readmeBase64)\"}"
                return HTTPResponseData(statusCode: 200, body: Data(json.utf8))
            }
            if path == "/api/v1/repos/octo/engineering-wiki/issues" {
                let json = """
                [{"number":7,"title":"补充内网部署文档","state":"open","user":{"login":"octo"},"labels":[{"name":"docs"}],"updated_at":"2026-11-14T10:00:00Z"}]
                """
                return HTTPResponseData(statusCode: 200, body: Data(json.utf8))
            }
            return HTTPResponseData(statusCode: 404, body: Data())
        }
        let client = GiteaClient(
            baseURL: "https://git.teapulse.example:8443",
            credentials: StoredCredentials(patToken: "pat"),
            transport: transport
        )

        let entries = try await client.fetchRepoContents(owner: "octo", repo: "engineering-wiki", ref: "main")
        #expect(entries.count == 2)
        #expect(entries[0].isDirectory == true)
        #expect(entries[0].path == "docs")
        #expect(entries[1].path == "README.md")

        let content = try await client.fetchRepoFileContent(owner: "octo", repo: "engineering-wiki", path: "docs/guide.md", ref: "main")
        #expect(content == "# engineering-wiki\nHello\n")

        let issues = try await client.fetchIssues(owner: "octo", repo: "engineering-wiki")
        #expect(issues.count == 1)
        #expect(issues[0].number == 7)
        #expect(issues[0].labels == ["docs"])
    }

    @Test("MarkdownBlockParser parses headings, tight lists, task items, code blocks, quotes, and tables")
    func markdownBlockParserCoverage() throws {
        let md = """
        ---
        title: Ignored Frontmatter
        ---
        # AGENTS.md

        Intro **bold** and `code`.
        - First item
        - [x] Done task

        > Important note

        ```text
        raw/
        ```

        | Layer | Role |
        | --- | --- |
        | wiki | Notes |
        """
        let blocks = MarkdownBlockParser.parse(md)
        #expect(blocks.count == 7)
        #expect(blocks[0].kind == .heading(level: 1, text: "AGENTS.md"))
        #expect(blocks[1].kind == .paragraph(text: "Intro **bold** and `code`."))
        #expect(blocks[2].kind == .listItem(indent: 0, marker: .bullet, text: "First item"))
        #expect(blocks[3].kind == .listItem(indent: 0, marker: .task(checked: true), text: "Done task"))
        #expect(blocks[4].kind == .blockquote(text: "Important note"))
        #expect(blocks[5].kind == .codeBlock(language: "text", code: "raw/"))
        #expect(blocks[6].kind == .table(headers: ["Layer", "Role"], rows: [["wiki", "Notes"]]))
    }

    @Test("Parses user activity feeds and builds fallback activities from repos and PRs")
    func parsesActivityFeedsAndFallback() async throws {
        let transport = MockHTTPTransport { request, _ in
            let path = request.url?.path ?? ""
            if path == "/api/v1/users/alex/activities/feeds" {
                let json = """
                [
                  {
                    "id": 101,
                    "op_type": "commit_repo",
                    "act_user": {"login": "alex"},
                    "repo": {"name": "engineering-wiki", "full_name": "octo/engineering-wiki", "owner": {"login": "octo"}},
                    "ref_name": "refs/heads/main",
                    "content": "{\\"Commits\\":[{\\"Message\\":\\"docs: update index\\\\nmore details\\"}]}",
                    "created": "2026-11-14T15:20:00Z"
                  },
                  {
                    "id": 102,
                    "op_type": "create_pull_request",
                    "act_user": {"username": "alice"},
                    "repo": {"name": "core", "full_name": "ops/core"},
                    "ref_name": "refs/heads/feat/tls",
                    "content": "42|feat: TLS probe",
                    "created": "2026-11-14T14:05:00Z"
                  },
                  {
                    "id": 103,
                    "op_type": 18,
                    "repo": {"name": "mirror-repo", "owner": {"login": "mirror"}},
                    "created": "2026-11-14T08:00:00Z"
                  }
                ]
                """
                return HTTPResponseData(statusCode: 200, body: Data(json.utf8))
            }
            return HTTPResponseData(statusCode: 404, body: Data())
        }
        let client = GiteaClient(
            baseURL: "https://git.teapulse.example:8443",
            credentials: StoredCredentials(patToken: "pat"),
            transport: transport
        )

        let events = try await client.fetchActivityFeeds(username: "alex")
        #expect(events.count == 3)
        #expect(events[0].actor == "alex")
        #expect(events[0].actionLabel == "推送提交：docs: update index")
        #expect(events[0].repoFullName == "octo/engineering-wiki")
        #expect(events[0].refText == "main")
        #expect(events[0].timestampText == "11-14 15:20")
        #expect(events[0].deepLink == "teapulse://repo/octo/engineering-wiki")

        #expect(events[1].actor == "alice")
        #expect(events[1].actionLabel == "发起合并请求 #42 feat: TLS probe")
        #expect(events[1].deepLink == "teapulse://pull/ops/core/42")

        #expect(events[2].actor == "mirror")
        #expect(events[2].actionLabel == "镜像同步推送")
        #expect(events[2].repoFullName == "mirror/mirror-repo")

        #expect(GiteaClient.buildFallbackActivities(repositories: [], pullRequests: []).isEmpty)
        let repo = RepositorySummary(
            id: "1", owner: "alex", name: "app", fullName: "alex/app",
            scope: .personal, isStarred: false, isMirror: false,
            defaultBranch: "main", stars: 1, openPRCount: 1, openIssueCount: 0,
            updatedAtText: "2026-11-14", cloneURL: "", sshURL: "", readmeMarkdown: "# app"
        )
        let pr = PullRequestDetail(
            id: "pr-1", number: 7, repoFullName: "alex/app", title: "Fix feed",
            author: "alex", headBranch: "fix", baseBranch: "main",
            state: .open, mergeable: true, additions: 3, deletions: 1
        )
        let fallback = GiteaClient.buildFallbackActivities(repositories: [repo], pullRequests: [pr])
        #expect(fallback.count == 2)
        #expect(fallback[0].deepLink == "teapulse://pull/alex/app/7")
        #expect(fallback[1].deepLink == "teapulse://repo/alex/app")
    }

    @Test("Paginates accessible repositories and fetches single repository by owner and name")
    func paginatesAndFetchesSingleRepository() async throws {
        let transport = MockHTTPTransport { request, _ in
            let url = request.url!
            let path = url.path
            if path == "/api/v1/user/repos" {
                let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "page" })?.value ?? "1"
                if page == "1" {
                    let entries = (1...50).map { idx in
                        #"{"id":\#(idx),"name":"repo-\#(idx)","full_name":"alex/repo-\#(idx)","owner":{"login":"alex","type":"User"},"updated_at":"2026-11-10T00:00:00Z"}"#
                    }.joined(separator: ",")
                    return HTTPResponseData(statusCode: 200, body: Data("[\(entries)]".utf8))
                }
                let page2 = #"[{"id":51,"name":"order-engine","full_name":"acme-cloud/order-engine","owner":{"login":"acme-cloud","type":"Organization"},"updated_at":"2026-11-14T06:48:00Z"}]"#
                return HTTPResponseData(statusCode: 200, body: Data(page2.utf8))
            }
            if path == "/api/v1/repos/acme-cloud/storefront" {
                let single = #"{"id":99,"name":"storefront","full_name":"acme-cloud/storefront","owner":{"login":"acme-cloud","type":"Organization"},"default_branch":"master","open_pr_counter":2}"#
                return HTTPResponseData(statusCode: 200, body: Data(single.utf8))
            }
            return HTTPResponseData(statusCode: 404, body: Data())
        }
        let client = GiteaClient(
            baseURL: "https://git.teapulse.example:8443",
            credentials: StoredCredentials(patToken: "pat"),
            transport: transport
        )

        let all = try await client.fetchAllAccessibleRepositories(currentUsername: "alex")
        #expect(all.count == 51)
        #expect(all.first?.fullName == "acme-cloud/order-engine")
        #expect(all.first?.scope == .org)

        let single = try await client.fetchRepository(owner: "acme-cloud", repo: "storefront", currentUsername: "alex")
        #expect(single.id == "99")
        #expect(single.defaultBranch == "master")
        #expect(single.openPRCount == 2)
        #expect(single.scope == .org)
    }

    @Test("Fetches notifications, repo actions runs, secrets, variables, PR comments, checks, and admin ops")
    func fetchesOpsAndWorkspaceExtensions() async throws {
        let transport = MockHTTPTransport { request, _ in
            let path = request.url?.path ?? ""
            let json: String
            switch path {
            case "/api/v1/notifications":
                json = #"[{"id":7,"unread":true,"updated_at":"2026-11-14T10:00:00Z","repository":{"full_name":"alex/app"},"subject":{"title":"PR review","type":"Pull","url":"https://git.example/pulls/12"}}]"#
            case "/api/v1/repos/alex/app/actions/secrets":
                json = #"[{"name":"DEPLOY_KEY","created_at":"2026-11-10T00:00:00Z"}]"#
            case "/api/v1/repos/alex/app/actions/variables":
                json = #"[{"name":"BUILD_ENV","data":"production"}]"#
            case "/api/v1/repos/alex/app/issues/12/comments":
                json = #"[{"id":5,"body":"LGTM","created_at":"2026-11-14T11:00:00Z","user":{"login":"alice"}}]"#
            case "/api/v1/repos/alex/app/commits/abc1234/status":
                json = #"{"statuses":[{"id":9,"context":"ci/test","status":"success"}]}"#
            case "/api/v1/repos/alex/app/actions/tasks":
                json = #"{"workflow_runs":[{"id":184,"display_title":"Build","head_branch":"main","head_sha":"abc123456","status":"failure","run_number":184,"workflow_id":"ci.yml"}]}"#
            case "/api/v1/admin/cron":
                json = #"[{"name":"purge_old_logs","schedule":"@daily","next":"2026-11-15","prev":"2026-11-14","exec_times":3}]"#
            case "/api/v1/admin/users":
                json = #"[{"id":1,"login":"alex","email":"alex@example.com","is_admin":true,"restricted":false,"prohibit_login":false}]"#
            default:
                return HTTPResponseData(statusCode: 404, body: Data())
            }
            return HTTPResponseData(statusCode: 200, body: Data(json.utf8))
        }
        let client = GiteaClient(baseURL: "https://git.teapulse.example:8443", credentials: StoredCredentials(patToken: "pat"), transport: transport)

        let notes = try await client.fetchNotifications()
        #expect(notes.count == 1)
        #expect(notes[0].deepLink == "teapulse://pull/alex/app/12")

        let secrets = try await client.fetchActionSecrets(owner: "alex", repo: "app")
        #expect(secrets.map(\.name) == ["DEPLOY_KEY"])

        let vars = try await client.fetchActionVariables(owner: "alex", repo: "app")
        #expect(vars.first?.value == "production")

        let comments = try await client.fetchPullRequestComments(owner: "alex", repo: "app", index: 12)
        #expect(comments.first?.author == "alice")

        let checks = try await client.fetchCommitChecks(owner: "alex", repo: "app", ref: "abc1234")
        #expect(checks.first?.status == .success)

        let runs = try await client.fetchRepoWorkflowRuns(owner: "alex", repo: "app", defaultBranch: "main")
        #expect(runs.first?.runNumber == 184)
        #expect(runs.first?.status == .failure)

        let crons = try await client.fetchAdminCronTasks()
        #expect(crons.first?.isDestructive == true)

        let users = try await client.fetchAdminUsers()
        #expect(users.first?.isAdmin == true)
    }

    @Test("Fetches user organizations, fetches org repos, and merges without duplicates")
    func fetchesAndMergesOrganizationRepositories() async throws {
        let transport = MockHTTPTransport { request, _ in
            let path = request.url?.path ?? ""
            let json: String
            switch path {
            case "/api/v1/user/orgs":
                json = """
                [
                  {"id":10,"username":"platform","name":"platform","full_name":"平台研发"},
                  {"id":11,"name":"mirror-hub","full_name":"上游镜像"}
                ]
                """
            case "/api/v1/orgs/platform/repos":
                json = """
                [
                  {"id":101,"name":"gateway","full_name":"platform/gateway","owner":{"login":"platform","type":"Organization"},"mirror":false,"updated_at":"2026-11-16T08:00:00Z"},
                  {"id":102,"name":"sdk","full_name":"platform/sdk","owner":{"login":"platform","type":"Organization"},"mirror":false,"updated_at":"2026-11-15T08:00:00Z"}
                ]
                """
            case "/api/v1/orgs/mirror-hub/repos":
                json = """
                [
                  {"id":103,"name":"swift-nio","full_name":"mirror-hub/swift-nio","owner":{"login":"mirror-hub","type":"Organization"},"mirror":true,"updated_at":"2026-11-16T08:00:00Z"}
                ]
                """
            default:
                return HTTPResponseData(statusCode: 404, body: Data())
            }
            return HTTPResponseData(statusCode: 200, body: Data(json.utf8))
        }
        let client = GiteaClient(
            baseURL: "https://git.teapulse.example:8443",
            credentials: StoredCredentials(patToken: "pat"),
            transport: transport
        )

        let orgs = try await client.fetchUserOrganizations()
        #expect(orgs.count == 2)
        #expect(orgs[0].username == "platform")
        #expect(orgs[0].fullName == "平台研发")
        #expect(orgs[1].username == "mirror-hub")
        #expect(orgs[1].fullName == "上游镜像")

        let platformRepos = try await client.fetchOrganizationRepositories(org: "platform", currentUsername: "alex")
        #expect(platformRepos.count == 2)
        #expect(platformRepos.allSatisfy { $0.isOrganizationOwned && $0.scope == .org })

        let seedGateway = RepositorySummary(
            id: "101", owner: "platform", name: "gateway", fullName: "platform/gateway",
            scope: .personal, isOrganizationOwned: false, isStarred: false, isMirror: false,
            defaultBranch: "main", stars: 5, openPRCount: 0, openIssueCount: 0,
            updatedAtText: "2026-11-16", cloneURL: "", sshURL: "", readmeMarkdown: ""
        )
        let merged = await client.mergeOrganizationRepositories(
            organizations: orgs,
            into: [seedGateway],
            currentUsername: "alex"
        )
        #expect(merged.count == 3)
        #expect(merged.map(\.fullName) == ["platform/gateway", "mirror-hub/swift-nio", "platform/sdk"])
        #expect(merged[0].scope == .org)
        #expect(merged[0].isOrganizationOwned == true)
        #expect(merged[1].scope == .mirror)
        #expect(merged[1].isOrganizationOwned == true)
    }
}
