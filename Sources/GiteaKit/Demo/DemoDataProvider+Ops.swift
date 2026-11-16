import Foundation

struct DemoRepoOpsFixtures: Sendable {
    let issuesByRepo: [String: [IssueItem]]
    let kanbanByRepo: [String: [KanbanCard]]
    let releasesByRepo: [String: [ReleaseItem]]
    let secretsByRepo: [String: [RepoSecretItem]]
    let variablesByRepo: [String: [RepoVariableItem]]
    let webhooksByRepo: [String: [WebhookConfig]]
}

struct DemoAdminFixtures: Sendable {
    let adminStats: AdminOverviewStats
    let cronTasks: [CronTaskItem]
    let adminUsers: [AdminUserItem]
    let packages: [PackageArtifactItem]
}

extension DemoDataProvider {
    static func makeRepoOpsFixtures() -> DemoRepoOpsFixtures {
        let issuesByRepo: [String: [IssueItem]] = [
            "alex/teapulse-core": [
                IssueItem(id: "iss-1", number: 12, title: "Release 大附件上传报 413 需引导检查 client_max_body_size", state: "open", author: "alex", labels: ["nginx", "upload"], blockedByNumbers: [], updatedAtText: "1h"),
                IssueItem(id: "iss-2", number: 15, title: "iOS 灵动岛接入实时构建进度", state: "open", author: "alex", labels: ["ios"], blockedByNumbers: [12], updatedAtText: "3h")
            ]
        ]

        let kanbanByRepo: [String: [KanbanCard]] = [
            "alex/teapulse-core": [
                KanbanCard(id: "kb-1", column: "待处理", title: "Release 413 提示", refNumber: 12, assignee: "alex"),
                KanbanCard(id: "kb-2", column: "进行中", title: ":8443 双端点探针", refNumber: 42, assignee: "alex"),
                KanbanCard(id: "kb-3", column: "已完成", title: "Keychain PAT 隔离", refNumber: 39, assignee: "alex")
            ]
        ]

        let releasesByRepo: [String: [ReleaseItem]] = [
            "alex/teapulse-core": [
                ReleaseItem(id: "rel-1", tagName: "v1.2.0", title: "Universal Proxy Engine", publishedAtText: "2d 前", assetNames: ["GiteaKit-v1.2.0.xcframework.zip"])
            ]
        ]

        let secretsByRepo: [String: [RepoSecretItem]] = [
            "alex/teapulse-core": [
                RepoSecretItem(id: "sec-1", name: "BARK_WEBHOOK_KEY", updatedAtText: "2d 前"),
                RepoSecretItem(id: "sec-2", name: "DEPLOY_SSH_KEY", updatedAtText: "5d 前")
            ]
        ]

        let variablesByRepo: [String: [RepoVariableItem]] = [
            "alex/teapulse-core": [
                RepoVariableItem(id: "var-1", name: "REGISTRY_HOST", value: "registry.teapulse.example:5000"),
                RepoVariableItem(id: "var-2", name: "MIN_IOS_SDK", value: "26.0")
            ]
        ]

        let webhooksByRepo: [String: [WebhookConfig]] = [
            "alex/teapulse-core": [
                WebhookConfig(
                    id: "wh-1",
                    numericID: 101,
                    targetURL: "https://n8n.teapulse.example/webhook/gitea-bark",
                    events: ["pull_request", "workflow_run"],
                    isActive: true,
                    lastStatusCode: 502,
                    deliveries: [
                        WebhookDelivery(id: "del-1", statusCode: 502, deliveredAtText: "14:20:05", eventName: "workflow_run", responseSummary: "Bad Gateway"),
                        WebhookDelivery(id: "del-2", statusCode: 200, deliveredAtText: "13:02:41", eventName: "pull_request", responseSummary: "OK")
                    ]
                )
            ]
        ]

        return DemoRepoOpsFixtures(
            issuesByRepo: issuesByRepo,
            kanbanByRepo: kanbanByRepo,
            releasesByRepo: releasesByRepo,
            secretsByRepo: secretsByRepo,
            variablesByRepo: variablesByRepo,
            webhooksByRepo: webhooksByRepo
        )
    }

    static func makeRuns(rawANSILog: String) -> [WorkflowRun] {
        [
            WorkflowRun(
                id: "run-184",
                runNumber: 184,
                jobID: 9184,
                repoFullName: "alex/web-deploy",
                workflowName: "build-and-push",
                workflowFile: "deploy.yml",
                branch: "main",
                commitSHA: "8f91c2a",
                status: .failure,
                runnerName: "runner-cloud-01",
                durationSeconds: 131,
                inputs: [
                    WorkflowDispatchInput(id: "in-env", key: "target_env", defaultValue: "staging", options: ["staging", "production"]),
                    WorkflowDispatchInput(id: "in-cache", key: "no_cache", defaultValue: "false", options: ["false", "true"])
                ],
                steps: ANSITerminalParser.parseSteps(from: rawANSILog, runFailed: true),
                artifacts: ["build-log-184.txt"]
            ),
            WorkflowRun(
                id: "run-185",
                runNumber: 185,
                jobID: 9185,
                repoFullName: "alex/teapulse-core",
                workflowName: "ci-matrix",
                workflowFile: "ci.yml",
                branch: "feat/nginx-probe",
                commitSHA: "3c44b19",
                status: .running,
                runnerName: "runner-nas-arm64",
                durationSeconds: 47,
                inputs: [
                    WorkflowDispatchInput(id: "in-suite", key: "suite", defaultValue: "full", options: ["quick", "full"])
                ],
                steps: [
                    WorkflowStepLog(
                        id: "st-1",
                        number: 1,
                        name: "XcodeGen & SwiftLint",
                        status: .success,
                        durationSeconds: 14,
                        isExpanded: false,
                        lines: [ANSITerminalLine(id: "l-1", lineNumber: 1, text: "Project spec validated.", severity: .success)]
                    ),
                    WorkflowStepLog(
                        id: "st-2",
                        number: 2,
                        name: "iOS 26.5 Simulator Test",
                        status: .running,
                        durationSeconds: 33,
                        isExpanded: true,
                        lines: [ANSITerminalLine(id: "l-2", lineNumber: 2, text: "Running EndpointProbeServiceTests...", severity: .info)]
                    )
                ],
                artifacts: []
            ),
            WorkflowRun(
                id: "run-186",
                runNumber: 186,
                jobID: 9186,
                repoFullName: "ops/nginx-gateway",
                workflowName: "prod-reload",
                workflowFile: "reload.yml",
                branch: "prod",
                commitSHA: "e910f44",
                status: .waitingApproval,
                runnerName: "runner-cloud-01",
                durationSeconds: 12,
                steps: [
                    WorkflowStepLog(
                        id: "st-wait",
                        number: 1,
                        name: "等待人工放行生产环境重载",
                        status: .waitingApproval,
                        durationSeconds: 12,
                        isExpanded: true,
                        lines: [ANSITerminalLine(id: "l-w", lineNumber: 1, text: "Pending maintainer approval.", severity: .warning)]
                    )
                ]
            )
        ]
    }

    static func makeRunners() -> [RunnerNode] {
        [
            RunnerNode(id: "rn-1", name: "runner-nas-arm64", hostLabel: "NAS Docker", status: .busy, labels: ["ubuntu-latest", "docker", "arm64"], activeJobTitle: "ci-matrix #185", version: "0.2.11"),
            RunnerNode(id: "rn-2", name: "runner-cloud-01", hostLabel: "HK Cloud", status: .online, labels: ["ubuntu-latest", "amd64"], activeJobTitle: nil, version: "0.2.11"),
            RunnerNode(id: "rn-3", name: "runner-edge-02", hostLabel: "Edge Node", status: .offline, labels: ["linux-arm64"], activeJobTitle: nil, version: "0.2.10")
        ]
    }

    static func makeNotifications() -> [NotificationThread] {
        [
            NotificationThread(id: "not-1", category: .mention, repoFullName: "alex/teapulse-core", subjectTitle: "PR #42 请求你评审", subjectType: "PullRequest", unread: true, updatedAtText: "10m", deepLink: "teapulse://pull/alex/teapulse-core/42"),
            NotificationThread(id: "not-2", category: .ciAlert, repoFullName: "alex/web-deploy", subjectTitle: "build-and-push #184 失败", subjectType: "WorkflowRun", unread: true, updatedAtText: "26m", deepLink: "teapulse://actions/alex/web-deploy/184?step=failed"),
            NotificationThread(id: "not-3", category: .pending, repoFullName: "ops/nginx-gateway", subjectTitle: "prod-reload #186 待审批", subjectType: "WorkflowRun", unread: true, updatedAtText: "34m", deepLink: "teapulse://actions/ops/nginx-gateway/186"),
            NotificationThread(id: "not-4", category: .archived, repoFullName: "mirror/swift-argument-parser", subjectTitle: "镜像已同步至 v1.5.0", subjectType: "Mirror", unread: false, updatedAtText: "1h", deepLink: "teapulse://repo/mirror/swift-argument-parser")
        ]
    }

    static func makeAdminFixtures() -> DemoAdminFixtures {
        let adminStats = AdminOverviewStats(
            serverVersion: "1.27.3",
            totalUsers: 4,
            totalRepos: 19,
            activeRunners: 2,
            offlineRunners: 1,
            packageCount: 7
        )

        let cronTasks = [
            CronTaskItem(id: "cron-1", name: "mirror_sync", schedule: "Every 10m", nextRunText: "04m 后", lastRunText: "06m 前", execTimes: 1420),
            CronTaskItem(id: "cron-2", name: "git_gc_repos", schedule: "Daily 03:00", nextRunText: "03:20 后", lastRunText: "20h 前", execTimes: 88, isDestructive: true),
            CronTaskItem(id: "cron-3", name: "cleanup_hook_task_table", schedule: "Weekly", nextRunText: "4d 后", lastRunText: "3d 前", execTimes: 21)
        ]

        let adminUsers = [
            AdminUserItem(id: "usr-1", login: "alex", email: "alex@teapulse.example", isAdmin: true, isRestricted: false, prohibitLogin: false, repoCount: 14),
            AdminUserItem(id: "usr-2", login: "ci-bot", email: "ci@teapulse.example", isAdmin: false, isRestricted: true, prohibitLogin: false, repoCount: 5),
            AdminUserItem(id: "usr-3", login: "guest-audit", email: "guest@teapulse.example", isAdmin: false, isRestricted: true, prohibitLogin: true, repoCount: 0)
        ]

        let packages = [
            PackageArtifactItem(id: "pkg-1", owner: "alex", type: "container", name: "teapulse-runner", version: "1.2.0", sizeLabel: "48 MB"),
            PackageArtifactItem(id: "pkg-2", owner: "ops", type: "generic", name: "nginx-gateway-conf", version: "2026.11", sizeLabel: "320 KB")
        ]

        return DemoAdminFixtures(
            adminStats: adminStats,
            cronTasks: cronTasks,
            adminUsers: adminUsers,
            packages: packages
        )
    }
}
