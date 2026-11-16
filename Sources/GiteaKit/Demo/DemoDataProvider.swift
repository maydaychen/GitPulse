import Foundation

public struct DemoSnapshot: Sendable {
    public var profile: InstanceProfile
    public var health: EndpointHealth
    public var triage: [TriageItem]
    public var pinnedRepos: [PinnedRepoSummary]
    public var heatmap: [HeatmapDay]
    public var activities: [ActivityEvent]
    public var repositories: [RepositorySummary]
    public var repoFiles: [String: [RepoFileEntry]]
    public var pullRequests: [PullRequestDetail]
    public var issuesByRepo: [String: [IssueItem]]
    public var kanbanByRepo: [String: [KanbanCard]]
    public var releasesByRepo: [String: [ReleaseItem]]
    public var secretsByRepo: [String: [RepoSecretItem]]
    public var variablesByRepo: [String: [RepoVariableItem]]
    public var webhooksByRepo: [String: [WebhookConfig]]
    public var runs: [WorkflowRun]
    public var runners: [RunnerNode]
    public var notifications: [NotificationThread]
    public var adminStats: AdminOverviewStats
    public var cronTasks: [CronTaskItem]
    public var adminUsers: [AdminUserItem]
    public var packages: [PackageArtifactItem]
    public var organizations: [OrganizationSummary]
    public var branchesByRepo: [String: [RepoBranchItem]]
    public var commitsByRepo: [String: [RepoCommitItem]]
    public var commitDiffsBySHA: [String: [DiffFilePatch]]

    public init(
        profile: InstanceProfile,
        health: EndpointHealth,
        triage: [TriageItem],
        pinnedRepos: [PinnedRepoSummary],
        heatmap: [HeatmapDay],
        activities: [ActivityEvent],
        repositories: [RepositorySummary],
        repoFiles: [String: [RepoFileEntry]],
        pullRequests: [PullRequestDetail],
        issuesByRepo: [String: [IssueItem]],
        kanbanByRepo: [String: [KanbanCard]],
        releasesByRepo: [String: [ReleaseItem]],
        secretsByRepo: [String: [RepoSecretItem]],
        variablesByRepo: [String: [RepoVariableItem]],
        webhooksByRepo: [String: [WebhookConfig]],
        runs: [WorkflowRun],
        runners: [RunnerNode],
        notifications: [NotificationThread],
        adminStats: AdminOverviewStats,
        cronTasks: [CronTaskItem],
        adminUsers: [AdminUserItem],
        packages: [PackageArtifactItem],
        organizations: [OrganizationSummary] = [],
        branchesByRepo: [String: [RepoBranchItem]] = [:],
        commitsByRepo: [String: [RepoCommitItem]] = [:],
        commitDiffsBySHA: [String: [DiffFilePatch]] = [:]
    ) {
        self.profile = profile
        self.health = health
        self.triage = triage
        self.pinnedRepos = pinnedRepos
        self.heatmap = heatmap
        self.activities = activities
        self.repositories = repositories
        self.repoFiles = repoFiles
        self.pullRequests = pullRequests
        self.issuesByRepo = issuesByRepo
        self.kanbanByRepo = kanbanByRepo
        self.releasesByRepo = releasesByRepo
        self.secretsByRepo = secretsByRepo
        self.variablesByRepo = variablesByRepo
        self.webhooksByRepo = webhooksByRepo
        self.runs = runs
        self.runners = runners
        self.notifications = notifications
        self.adminStats = adminStats
        self.cronTasks = cronTasks
        self.adminUsers = adminUsers
        self.packages = packages
        self.organizations = organizations
        self.branchesByRepo = branchesByRepo
        self.commitsByRepo = commitsByRepo
        self.commitDiffsBySHA = commitDiffsBySHA
    }
}

public enum DemoDataProvider {
    public static func makeSnapshot() -> DemoSnapshot {
        let profile = InstanceProfile(
            id: "demo-gitea",
            displayName: "Demo Gitea",
            publicURL: "https://git.teapulse.example:8443",
            lanURL: "http://10.0.0.18:23000",
            sshPortOverride: 2222,
            activeChannel: .publicProxy,
            barkEndpointURL: "https://bark.teapulse.example/push",
            username: "alex"
        )
        let health = EndpointHealth(
            channel: .publicProxy,
            baseURL: profile.publicURL,
            latencyMs: 22,
            serverVersion: "1.27.3"
        )

        let rawDiff = """
        diff --git a/Sources/Networking/EndpointProbe.swift b/Sources/Networking/EndpointProbe.swift
        index 11a2b3c..99d8e7f 100644
        --- a/Sources/Networking/EndpointProbe.swift
        +++ b/Sources/Networking/EndpointProbe.swift
        @@ -14,7 +14,9 @@ public actor EndpointProbe {
             public func selectBaseURL() async -> String {
        -        return publicProxyURL
        +        if await pingHealthz(url: lanDirectURL, timeoutMs: 800) {
        +            return lanDirectURL
        +        }
        +        return publicProxyURL
             }
         }
        diff --git a/nginx/gitea-proxy.conf b/nginx/gitea-proxy.conf
        index 45a11b2..77c2019 100644
        --- a/nginx/gitea-proxy.conf
        +++ b/nginx/gitea-proxy.conf
        @@ -8,3 +8,4 @@ server {
             proxy_pass http://127.0.0.1:3000;
        +    proxy_buffering off;
         }
        """

        let rawANSILog = """
        ::group::检出代码
        \u{001B}[36mSyncing repository refs/pull/42/head...\u{001B}[0m
        \u{001B}[32mChecked out commit 8f91c2a\u{001B}[0m
        ::endgroup::
        ::group::Swift 并发与集成测试
        Building GiteaKit in Release mode...
        \u{001B}[33mwarning: EndpointProbeTests latency threshold tight (800ms)\u{001B}[0m
        \u{001B}[31merror: testNginxPortPreservation failed: expected :8443, got 443\u{001B}[0m
        Assertion failed at EndpointTests.swift:84
        ::endgroup::
        """

        let triage = [
            TriageItem(
                id: "tr-pr-42",
                kind: .pullRequest,
                priority: 1,
                repoFullName: "alex/teapulse-core",
                title: "feat: 支持 :8443 反代与内网双端点探针",
                subtitlePill: "feat/nginx-probe -> main",
                metricText: "+128 -24",
                deepLink: "teapulse://pull/alex/teapulse-core/42"
            ),
            TriageItem(
                id: "tr-run-184",
                kind: .failedRun,
                priority: 2,
                repoFullName: "alex/web-deploy",
                title: "build-and-push #184 构建失败",
                subtitlePill: "runner-cloud-01",
                metricText: "02:11",
                deepLink: "teapulse://actions/alex/web-deploy/184?step=failed"
            ),
            TriageItem(
                id: "tr-runner-off",
                kind: .offlineRunner,
                priority: 3,
                repoFullName: "act_runner",
                title: "runner-edge-02 心跳超时",
                subtitlePill: "离线",
                metricText: "6m",
                deepLink: "teapulse://ops/runners"
            )
        ]

        let pinnedRepos = [
            PinnedRepoSummary(id: "pin-1", fullName: "alex/teapulse-core", defaultBranch: "main", openPRCount: 2, ciStatus: .running),
            PinnedRepoSummary(id: "pin-2", fullName: "alex/web-deploy", defaultBranch: "main", openPRCount: 1, ciStatus: .failure),
            PinnedRepoSummary(id: "pin-3", fullName: "ops/nginx-gateway", defaultBranch: "prod", openPRCount: 0, ciStatus: .success),
            PinnedRepoSummary(id: "pin-4", fullName: "mirror/swift-argument-parser", defaultBranch: "main", openPRCount: 0, ciStatus: .success, isMirror: true)
        ]

        let today = Date()
        let heatmap = (0..<112).map { offset -> HeatmapDay in
            let day = Calendar.current.date(byAdding: .day, value: -(111 - offset), to: today) ?? today
            let count = (offset * 7 + (offset % 5) * 3) % 9
            return HeatmapDay(id: "hm-\(offset)", date: day, contributions: count)
        }

        let activities = [
            ActivityEvent(id: "act-1", actor: "alex", actionLabel: "打开了 PR #42", repoFullName: "alex/teapulse-core", refText: "feat/nginx-probe", timestampText: "12m", deepLink: "teapulse://pull/alex/teapulse-core/42"),
            ActivityEvent(id: "act-2", actor: "act_runner", actionLabel: "Run #184 失败", repoFullName: "alex/web-deploy", refText: "main", timestampText: "26m", deepLink: "teapulse://actions/alex/web-deploy/184?step=failed"),
            ActivityEvent(id: "act-3", actor: "cron", actionLabel: "镜像同步完成", repoFullName: "mirror/swift-argument-parser", refText: "1.5.0", timestampText: "1h", deepLink: "teapulse://repo/mirror/swift-argument-parser")
        ]

        let readmeCore = """
        # teapulse-core

        Gitea 1.27+ 反代与双端点探测核心模块。

        ```mermaid
        flowchart LR
            A[App 激活] -->|800ms healthz| B[LAN :23000]
            A -->|Fallback| C[Nginx TLS :8443]
            B --> D[Gitea 1.27.3]
            C --> D
        ```
        """

        let repositories = [
            RepositorySummary(
                id: "repo-1",
                owner: "alex",
                name: "teapulse-core",
                fullName: "alex/teapulse-core",
                scope: .personal,
                isStarred: true,
                isMirror: false,
                defaultBranch: "main",
                stars: 28,
                openPRCount: 2,
                openIssueCount: 3,
                updatedAtText: "12m 前",
                cloneURL: "https://git.teapulse.example:8443/alex/teapulse-core.git",
                sshURL: "ssh://git@git.teapulse.example:2222/alex/teapulse-core.git",
                readmeMarkdown: readmeCore
            ),
            RepositorySummary(
                id: "repo-2",
                owner: "alex",
                name: "web-deploy",
                fullName: "alex/web-deploy",
                scope: .personal,
                isStarred: false,
                isMirror: false,
                defaultBranch: "main",
                stars: 11,
                openPRCount: 1,
                openIssueCount: 2,
                updatedAtText: "26m 前",
                cloneURL: "https://git.teapulse.example:8443/alex/web-deploy.git",
                sshURL: "ssh://git@git.teapulse.example:2222/alex/web-deploy.git",
                readmeMarkdown: "# web-deploy\n\nDocker Compose + act_runner 自动发布流。\n"
            ),
            RepositorySummary(
                id: "repo-3",
                owner: "ops",
                name: "nginx-gateway",
                fullName: "ops/nginx-gateway",
                scope: .org,
                isStarred: true,
                isMirror: false,
                defaultBranch: "prod",
                stars: 16,
                openPRCount: 0,
                openIssueCount: 1,
                updatedAtText: "3h 前",
                cloneURL: "https://git.teapulse.example:8443/ops/nginx-gateway.git",
                sshURL: "ssh://git@git.teapulse.example:2222/ops/nginx-gateway.git",
                readmeMarkdown: "# nginx-gateway\n\n`:8443` TLS 终结与 `proxy_buffering off` 配置模板。\n"
            ),
            RepositorySummary(
                id: "repo-4",
                owner: "mirror",
                name: "swift-argument-parser",
                fullName: "mirror/swift-argument-parser",
                scope: .mirror,
                isOrganizationOwned: true,
                isStarred: true,
                isMirror: true,
                mirrorInterval: "4h0m0s",
                lastMirrorSyncText: "1h 前",
                defaultBranch: "main",
                stars: 9,
                openPRCount: 0,
                openIssueCount: 0,
                updatedAtText: "1h 前",
                cloneURL: "https://git.teapulse.example:8443/mirror/swift-argument-parser.git",
                sshURL: "ssh://git@git.teapulse.example:2222/mirror/swift-argument-parser.git",
                readmeMarkdown: "# swift-argument-parser (Mirror)\n\n自动从上游镜像同步。\n"
            )
        ]

        let repoFiles: [String: [RepoFileEntry]] = [
            "alex/teapulse-core": [
                RepoFileEntry(id: "f-1", name: "Package.swift", path: "Package.swift", isDirectory: false, sizeBytes: 642, sha: "a11b2c", content: "// swift-tools-version: 6.0\nimport PackageDescription\n"),
                RepoFileEntry(id: "f-2", name: "Sources/Networking/EndpointProbe.swift", path: "Sources/Networking/EndpointProbe.swift", isDirectory: false, sizeBytes: 1840, sha: "b22c3d", content: "public actor EndpointProbe {\n    public func selectBaseURL() async -> String { ... }\n}\n"),
                RepoFileEntry(id: "f-3", name: "nginx/gitea-proxy.conf", path: "nginx/gitea-proxy.conf", isDirectory: false, sizeBytes: 512, sha: "c33d4e", content: "server {\n    listen 8443 ssl;\n    proxy_buffering off;\n}\n")
            ]
        ]

        let pullRequests = [
            PullRequestDetail(
                id: "pr-42",
                number: 42,
                repoFullName: "alex/teapulse-core",
                title: "feat: 支持 :8443 反代与内网双端点探针",
                author: "alex",
                headBranch: "feat/nginx-probe",
                baseBranch: "main",
                state: .open,
                mergeable: true,
                additions: 128,
                deletions: 24,
                stackPosition: 1,
                stackTotal: 2,
                checks: [
                    CICheckItem(id: "chk-1", name: "Swift Strict Concurrency", status: .success, durationText: "00:48", deepLink: "teapulse://actions/alex/teapulse-core/185"),
                    CICheckItem(id: "chk-2", name: "Proxy Port Probe Matrix", status: .running, durationText: "00:34", deepLink: "teapulse://actions/alex/teapulse-core/185")
                ],
                comments: [
                    PRTimelineComment(
                        id: "c-1",
                        author: "review-bot",
                        body: "内网健康探针超时控制在 800ms。",
                        filePath: "Sources/Networking/EndpointProbe.swift",
                        lineNumber: 16,
                        timestampText: "10m"
                    )
                ],
                files: UnifiedDiffParser.parse(rawDiff)
            ),
            PullRequestDetail(
                id: "pr-43",
                number: 43,
                repoFullName: "alex/teapulse-core",
                title: "feat: 添加 Stacked PR 合并列车自动变基",
                author: "alex",
                headBranch: "feat/stack-train",
                baseBranch: "feat/nginx-probe",
                state: .open,
                mergeable: true,
                additions: 64,
                deletions: 12,
                stackPosition: 2,
                stackTotal: 2,
                checks: [
                    CICheckItem(id: "chk-3", name: "Unit Tests", status: .success, durationText: "00:31", deepLink: "teapulse://actions/alex/teapulse-core/185")
                ]
            ),
            PullRequestDetail(
                id: "pr-19",
                number: 19,
                repoFullName: "alex/web-deploy",
                title: "fix: 关闭 SSE 日志缓冲防卡死",
                author: "alex",
                headBranch: "fix/proxy-buffer",
                baseBranch: "main",
                state: .open,
                mergeable: true,
                additions: 14,
                deletions: 3
            )
        ]

        let ops = makeRepoOpsFixtures()
        let runs = makeRuns(rawANSILog: rawANSILog)
        let runners = makeRunners()
        let notifications = makeNotifications()
        let admin = makeAdminFixtures()
        let organizations = [
            OrganizationSummary(id: "org-ops", username: "ops", fullName: "基础设施"),
            OrganizationSummary(id: "org-mirror", username: "mirror", fullName: "上游镜像")
        ]
        let sampleDiff = UnifiedDiffParser.parse(rawDiff)
        let branchesByRepo: [String: [RepoBranchItem]] = [
            "alex/teapulse-core": [
                RepoBranchItem(id: "br-core-main", name: "main", commitSHA: "a7c91e3", isDefault: true, isTag: false),
                RepoBranchItem(id: "br-core-stacked", name: "feat/stacked-diff", commitSHA: "c83d210", isDefault: false, isTag: false),
                RepoBranchItem(id: "tag-core-010", name: "v0.1.0", commitSHA: "a7c91e3", isDefault: false, isTag: true)
            ],
            "alex/web-deploy": [
                RepoBranchItem(id: "br-web-main", name: "main", commitSHA: "91d4f02", isDefault: true, isTag: false),
                RepoBranchItem(id: "br-web-fix", name: "fix/proxy-buffer", commitSHA: "e12b7a9", isDefault: false, isTag: false)
            ],
            "ops/nginx-gateway": [
                RepoBranchItem(id: "br-ops-prod", name: "prod", commitSHA: "4b218aa", isDefault: true, isTag: false)
            ]
        ]
        let commitsByRepo: [String: [RepoCommitItem]] = [
            "alex/teapulse-core": [
                RepoCommitItem(
                    id: "cm-a7c91e3",
                    sha: "a7c91e3",
                    shortSHA: "a7c91e3",
                    title: "feat: 支持 :8443 反代与内网 800ms 探针",
                    message: "feat: 支持 :8443 反代与内网 800ms 探针",
                    author: "alex",
                    timestampText: "2026-11-16",
                    filesChangedCount: sampleDiff.count
                ),
                RepoCommitItem(
                    id: "cm-c83d210",
                    sha: "c83d210",
                    shortSHA: "c83d210",
                    title: "refactor: 优化 ANSI 日志流式切片解析",
                    message: "refactor: 优化 ANSI 日志流式切片解析",
                    author: "alex",
                    timestampText: "2026-11-15",
                    filesChangedCount: 1
                )
            ],
            "ops/nginx-gateway": [
                RepoCommitItem(
                    id: "cm-4b218aa",
                    sha: "4b218aa",
                    shortSHA: "4b218aa",
                    title: "chore(nginx): 关闭大文件上传与 SSE 响应缓冲",
                    message: "chore(nginx): 关闭大文件上传与 SSE 响应缓冲",
                    author: "ops-bot",
                    timestampText: "2026-11-16",
                    filesChangedCount: sampleDiff.count
                )
            ]
        ]
        let commitDiffsBySHA: [String: [DiffFilePatch]] = [
            "a7c91e3": sampleDiff,
            "c83d210": sampleDiff,
            "4b218aa": sampleDiff
        ]

        return DemoSnapshot(
            profile: profile,
            health: health,
            triage: triage,
            pinnedRepos: pinnedRepos,
            heatmap: heatmap,
            activities: activities,
            repositories: repositories,
            repoFiles: repoFiles,
            pullRequests: pullRequests,
            issuesByRepo: ops.issuesByRepo,
            kanbanByRepo: ops.kanbanByRepo,
            releasesByRepo: ops.releasesByRepo,
            secretsByRepo: ops.secretsByRepo,
            variablesByRepo: ops.variablesByRepo,
            webhooksByRepo: ops.webhooksByRepo,
            runs: runs,
            runners: runners,
            notifications: notifications,
            adminStats: admin.adminStats,
            cronTasks: admin.cronTasks,
            adminUsers: admin.adminUsers,
            packages: admin.packages,
            organizations: organizations,
            branchesByRepo: branchesByRepo,
            commitsByRepo: commitsByRepo,
            commitDiffsBySHA: commitDiffsBySHA
        )
    }
}
