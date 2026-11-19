import Foundation
import Network
import Observation
import SwiftUI
import GiteaKit

public enum ThemePreference: String, CaseIterable, Identifiable, Sendable {
    case system = "自动"
    case dark = "深色"
    case light = "浅色"

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    public var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .dark: return "moon.stars.fill"
        case .light: return "sun.max.fill"
        }
    }
}

public struct LoginDiagnosticStep: Identifiable, Equatable, Sendable {
    public enum State: Sendable {
        case pending
        case running
        case passed
        case warning
        case failed
    }

    public let id: String
    public let title: String
    public let detail: String
    public let state: State

    public init(id: String, title: String, detail: String, state: State) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
    }
}

@MainActor
@Observable
public final class AppStore {
    public var selectedSection: AppSection = .pulse
    public var themePreference: ThemePreference = .dark {
        didSet {
            defaults.set(themePreference.rawValue, forKey: themeStorageKey)
        }
    }
    public var isDemoMode: Bool
    public var isLoginGatePresented: Bool
    public var profile: InstanceProfile
    public var health: EndpointHealth
    public var proxyLatencyMs: Int = 0
    public var lanLatencyMs: Int = 0
    public var triage: [TriageItem]
    public var pinnedRepos: [PinnedRepoSummary]
    public var heatmap: [HeatmapDay]
    public var activities: [ActivityEvent]
    public var organizations: [OrganizationSummary]
    public var repositories: [RepositorySummary]
    public var branchesByRepo: [String: [RepoBranchItem]]
    public var commitsByRepo: [String: [RepoCommitItem]]
    public var commitDiffsBySHA: [String: [DiffFilePatch]]
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

    // Active selections & filters
    public var repoScopeFilter: RepoScope = .all
    public var selectedOrganizationFilter: String? = nil
    public var repoSearchQuery = ""
    public var selectedBranchByRepo: [String: String] = [:]
    public var selectedRepoID: String?
    public var selectedRepoTab: RepoWorkspaceTab = .readme
    public var selectedPRID: String?
    public var selectedPRSegment: PullRequestSegment = .overview
    public var actionsFilter: ActionsFilterScope = .all
    public var selectedRunID: String?
    public var inboxCategory: NotificationCategory = .pending
    public var showAllInbox = true
    public var isCommandPalettePresented = false
    public var isConnectionSheetPresented = false
    public var simulatedPushBanner: NotificationThread?
    public var approvedPRIDs: Set<String> = []
    public var statusToast: String?
    public var statusToastTone: ToastTone = .success
    public var lastRunnerRegistrationToken: String?
    public var pendingInlineDrafts: [String: [InlineReviewDraft]] = [:]

    internal let credentialStore: CredentialStore
    internal let probeService: EndpointProbeService
    internal let transport: HTTPTransport
    internal var connectionAttemptID: UUID?
    internal var hasLoadedLiveWorkspace = false
    public internal(set) var isLoadingWorkspace = false
    public internal(set) var isResolvingRoute = false
    internal var loadingRepoNames: Set<String> = []
    internal var loadedRepoNames: Set<String> = []
    internal var loadingPRIDs: Set<String> = []
    internal var loadedPRIDs: Set<String> = []
    internal var loadingRunIDs: Set<String> = []
    internal var loadedRunIDs: Set<String> = []
    internal var lastWorkspaceRefreshAt: Date?
    internal var lastSyncedWidgetFingerprint: String?
    internal var loadedRepoTabTimestamps: [String: Date] = [:]
    internal var commitDiffOrder: [String] = []
    internal var loadedFileContentOrder: [String] = []
    internal var loadedRunLogOrder: [String] = []
    internal var pendingRoute: TeaPulseRoute?
    public internal(set) var routeNavigationID = 0
    internal let defaults: UserDefaults
    private let writesWidgetSnapshot: Bool
    private let liveActivity: any LiveActivityCoordinating
    private var pathMonitor: NWPathMonitor?
    internal let profileStorageKey = "teapulse.saved.profile.v1"
    private let themeStorageKey = "teapulse.theme.preference.v1"

    public init(
        credentialStore: CredentialStore = KeychainCredentialStore(),
        transport: HTTPTransport = URLSessionHTTPTransport(),
        forceDemoMode: Bool = false,
        defaults: UserDefaults = .standard,
        writesWidgetSnapshot: Bool = true,
        liveActivity: any LiveActivityCoordinating = LiveActivityCoordinator()
    ) {
        self.credentialStore = credentialStore
        self.transport = transport
        self.defaults = defaults
        self.writesWidgetSnapshot = writesWidgetSnapshot
        self.liveActivity = liveActivity
        self.probeService = EndpointProbeService(transport: transport)

        let demo = DemoDataProvider.makeSnapshot()
        let savedProfile = Self.loadSavedProfile(key: profileStorageKey, defaults: defaults)
        let args = ProcessInfo.processInfo.arguments
        let isUITesting = args.contains("--demo-mode")
        let forceLoginScreen = args.contains("--login-screen")
        let shouldUseDemo = forceDemoMode || isUITesting

        if let savedTheme = defaults.string(forKey: "teapulse.theme.preference.v1"),
           let parsedTheme = ThemePreference(rawValue: savedTheme) {
            self.themePreference = parsedTheme
        }

        self.isDemoMode = shouldUseDemo
        self.isLoginGatePresented = forceLoginScreen || (!forceDemoMode && !isUITesting && savedProfile == nil)
        let initialProfile = shouldUseDemo ? demo.profile : (savedProfile ?? InstanceProfile(id: "unconfigured", displayName: "Gitea", publicURL: ""))
        self.profile = initialProfile
        self.proxyLatencyMs = shouldUseDemo ? 22 : 0
        self.lanLatencyMs = shouldUseDemo ? 3 : 0
        self.health = shouldUseDemo
            ? EndpointHealth(channel: .publicProxy, baseURL: demo.profile.publicURL, latencyMs: 22, serverVersion: "1.27.3")
            : EndpointHealth(channel: initialProfile.activeChannel, baseURL: initialProfile.publicURL, latencyMs: 0, serverVersion: "unreachable")
        self.triage = shouldUseDemo ? demo.triage : []
        self.pinnedRepos = shouldUseDemo ? demo.pinnedRepos : []
        self.heatmap = shouldUseDemo ? demo.heatmap : []
        self.activities = shouldUseDemo ? demo.activities : []
        self.organizations = shouldUseDemo ? demo.organizations : []
        self.repositories = shouldUseDemo ? demo.repositories : []
        self.branchesByRepo = shouldUseDemo ? demo.branchesByRepo : [:]
        self.commitsByRepo = shouldUseDemo ? demo.commitsByRepo : [:]
        self.commitDiffsBySHA = shouldUseDemo ? demo.commitDiffsBySHA : [:]
        self.repoFiles = shouldUseDemo ? demo.repoFiles : [:]
        self.pullRequests = shouldUseDemo ? demo.pullRequests : []
        self.issuesByRepo = shouldUseDemo ? demo.issuesByRepo : [:]
        self.kanbanByRepo = shouldUseDemo ? demo.kanbanByRepo : [:]
        self.releasesByRepo = shouldUseDemo ? demo.releasesByRepo : [:]
        self.secretsByRepo = shouldUseDemo ? demo.secretsByRepo : [:]
        self.variablesByRepo = shouldUseDemo ? demo.variablesByRepo : [:]
        self.webhooksByRepo = shouldUseDemo ? demo.webhooksByRepo : [:]
        self.runs = shouldUseDemo ? demo.runs : []
        self.runners = shouldUseDemo ? demo.runners : []
        self.notifications = shouldUseDemo ? demo.notifications : []
        self.adminStats = shouldUseDemo ? demo.adminStats : AdminOverviewStats(serverVersion: "未加载", totalUsers: 0, totalRepos: 0, activeRunners: 0, offlineRunners: 0, packageCount: 0)
        self.cronTasks = shouldUseDemo ? demo.cronTasks : []
        self.adminUsers = shouldUseDemo ? demo.adminUsers : []
        self.packages = shouldUseDemo ? demo.packages : []
        self.selectedRepoID = shouldUseDemo ? demo.repositories.first?.id : nil
        self.selectedPRID = shouldUseDemo ? demo.pullRequests.first?.id : nil
        self.selectedRunID = shouldUseDemo ? demo.runs.first?.id : nil
        self.isLoadingWorkspace = !shouldUseDemo && !self.isLoginGatePresented

        syncWidgetSnapshot()
    }

    public var unreadInboxCount: Int {
        notifications.filter { $0.unread }.count
    }

    public var filteredRuns: [WorkflowRun] {
        runs.filter { run in
            switch actionsFilter {
            case .all: return true
            case .running: return run.status == .running
            case .waiting: return run.status == .waitingApproval
            case .failed: return run.status == .failure
            case .runners: return true
            }
        }
    }

    public var filteredNotifications: [NotificationThread] {
        if showAllInbox {
            return notifications
        }
        return notifications.filter { $0.category == inboxCategory }
    }

    public var selectedRepository: RepositorySummary? {
        repositories.first { $0.id == selectedRepoID }
    }

    public var selectedPullRequest: PullRequestDetail? {
        pullRequests.first { $0.id == selectedPRID }
    }

    public var selectedRun: WorkflowRun? {
        runs.first { $0.id == selectedRunID }
    }

    public var commandPaletteEntries: [CommandPaletteEntry] {
        var list: [CommandPaletteEntry] = []
        list.append(contentsOf: repositories.map {
            CommandPaletteEntry(
                id: "cmd-\($0.id)",
                title: $0.fullName,
                subtitle: $0.defaultBranch,
                badge: $0.isMirror ? "镜像" : "仓库",
                deepLink: "teapulse://repo/\($0.fullName)"
            )
        })
        list.append(contentsOf: pullRequests.map {
            CommandPaletteEntry(
                id: "cmd-\($0.id)",
                title: "#\($0.number) \($0.title)",
                subtitle: $0.repoFullName,
                badge: "合并请求",
                deepLink: "teapulse://pull/\($0.repoFullName)/\($0.number)"
            )
        })
        list.append(contentsOf: runs.map {
            CommandPaletteEntry(
                id: "cmd-\($0.id)",
                title: "\($0.workflowName) #\($0.runNumber)",
                subtitle: $0.repoFullName,
                badge: $0.status.badgeLabel,
                deepLink: "teapulse://actions/\($0.repoFullName)/\($0.runNumber)\($0.status == .failure ? "?step=failed" : "")"
            )
        })
        list.append(CommandPaletteEntry(
            id: "cmd-runners",
            title: "执行节点在线监控",
            subtitle: "\(runners.filter { $0.status != .offline }.count)/\(runners.count) 在线",
            badge: "运维",
            deepLink: "teapulse://ops/runners"
        ))
        return list
    }

    public func startNetworkMonitoring() {
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshEndpointProbe()
            }
        }
        monitor.start(queue: DispatchQueue(label: "com.maydaychen.teapulse.netprobe"))
        pathMonitor = monitor
    }

    public func refreshEndpointProbe() async {
        if isDemoMode {
            let isLAN = profile.activeChannel == .lanDirect && (profile.lanURL?.isEmpty == false)
            let channel: EndpointChannel = isLAN ? .lanDirect : .publicProxy
            let url = isLAN ? (profile.lanURL ?? profile.publicURL) : profile.publicURL
            let latency = isLAN ? lanLatencyMs : proxyLatencyMs
            health = EndpointHealth(
                channel: channel,
                baseURL: url,
                latencyMs: latency,
                serverVersion: "1.27.3"
            )
            syncWidgetSnapshot()
            return
        }
        let probingProfile = profile
        guard !probingProfile.publicURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            health = EndpointHealth(channel: probingProfile.activeChannel, baseURL: "", latencyMs: 0, serverVersion: "unreachable")
            syncWidgetSnapshot()
            return
        }
        let headers = credentialStore.loadCredentials(forProfileID: probingProfile.id)?.customHeaders ?? [:]
        async let proxyTask = probeService.measureHealthz(
            baseURL: probingProfile.publicURL,
            channel: .publicProxy,
            timeout: 4.0,
            additionalHeaders: headers
        )
        let lanTrimmed = probingProfile.lanURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        async let lanTask: EndpointHealth? = lanTrimmed.isEmpty ? nil : probeService.measureHealthz(
            baseURL: lanTrimmed,
            channel: .lanDirect,
            timeout: 0.8,
            additionalHeaders: headers
        )
        let (proxyHealth, lanHealth) = await (proxyTask, lanTask)
        guard !isDemoMode, profile == probingProfile else { return }

        proxyLatencyMs = proxyHealth?.latencyMs ?? 0
        lanLatencyMs = lanHealth?.latencyMs ?? 0

        let resolved: EndpointHealth?
        switch probingProfile.activeChannel {
        case .lanDirect:
            if let lanHealth {
                resolved = lanHealth
            } else if let proxyHealth {
                profile.activeChannel = .publicProxy
                Self.saveProfile(profile, key: profileStorageKey, defaults: defaults)
                resolved = proxyHealth
            } else {
                resolved = nil
            }
        case .publicProxy, .demo:
            if let proxyHealth {
                resolved = proxyHealth
            } else if let lanHealth {
                profile.activeChannel = .lanDirect
                Self.saveProfile(profile, key: profileStorageKey, defaults: defaults)
                resolved = lanHealth
            } else {
                resolved = nil
            }
        }

        if let resolved {
            health = EndpointHealth(
                channel: resolved.channel, baseURL: resolved.baseURL,
                latencyMs: resolved.latencyMs, serverVersion: resolvedServerVersion(from: resolved.serverVersion)
            )
        } else {
            let activeBase = probingProfile.activeChannel == .lanDirect
                ? (probingProfile.lanURL ?? probingProfile.publicURL)
                : probingProfile.publicURL
            health = EndpointHealth(
                channel: probingProfile.activeChannel, baseURL: activeBase,
                latencyMs: 0, serverVersion: "unreachable"
            )
        }
        syncWidgetSnapshot()
    }

    public func updateBarkEndpoint(_ rawURL: String?) {
        let trimmed = rawURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        profile.barkEndpointURL = trimmed.isEmpty ? nil : trimmed
        if !isDemoMode { Self.saveProfile(profile, key: profileStorageKey, defaults: defaults) }
        showToast("已保存推送设置")
    }

    public func runOnboardingHandshake(
        publicURL: String, lanURL: String?, patToken: String,
        preferredChannel: EndpointChannel, customHeaders: [String: String] = [:]
    ) async -> [LoginDiagnosticStep] {
        let cleanPublic = publicURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLAN = lanURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateURL = (preferredChannel == .lanDirect && cleanLAN?.isEmpty == false)
            ? (cleanLAN ?? cleanPublic) : cleanPublic
        guard let parsed = try? GiteaURLBuilder.healthzURL(baseURLString: candidateURL) else {
            return [
                LoginDiagnosticStep(id: "s1", title: "URL 与反代端口解析", detail: "地址格式无效，请检查协议与端口", state: .failed),
                LoginDiagnosticStep(id: "s2", title: "/api/healthz 实例探针", detail: "等待地址修正", state: .pending),
                LoginDiagnosticStep(id: "s3", title: "PAT 身份验证", detail: "等待健康握手", state: .pending)
            ]
        }
        let portBadge = parsed.port.map { ":\($0)" } ?? (parsed.scheme == "https" ? ":443" : ":80")
        let step1 = LoginDiagnosticStep(id: "s1", title: "URL 与反代端口解析", detail: "\(parsed.host ?? candidateURL)\(portBadge)", state: .passed)
        guard let probed = await probeService.measureHealthz(
            baseURL: candidateURL, channel: preferredChannel,
            timeout: preferredChannel == .lanDirect ? 0.8 : 3.5, additionalHeaders: customHeaders
        ) else {
            return [
                step1,
                LoginDiagnosticStep(id: "s2", title: "/api/healthz 实例探针", detail: "当前网络不可达（可检查反代端口或改用演示工作台）", state: .warning),
                LoginDiagnosticStep(id: "s3", title: "PAT 身份验证", detail: patToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "待输入 PAT" : "已就绪，待实例连通后验证", state: .pending)
            ]
        }
        if preferredChannel == .lanDirect { lanLatencyMs = probed.latencyMs } else { proxyLatencyMs = probed.latencyMs }
        let step2 = LoginDiagnosticStep(id: "s2", title: "/api/healthz 实例探针", detail: "Gitea \(probed.serverVersion) · \(probed.latencyMs)ms", state: .passed)
        let trimmedPAT = patToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPAT.isEmpty else {
            return [step1, step2, LoginDiagnosticStep(id: "s3", title: "PAT 身份验证", detail: "未填写 PAT，请粘贴令牌后接入", state: .warning)]
        }
        let client = GiteaClient(baseURL: candidateURL, credentials: StoredCredentials(patToken: trimmedPAT, customHeaders: customHeaders), transport: transport)
        do {
            let login = try await client.fetchCurrentUserLogin()
            return [step1, step2, LoginDiagnosticStep(id: "s3", title: "PAT 身份验证", detail: "已验证 @\(login)，操作权限以接口响应为准", state: .passed)]
        } catch {
            return [step1, step2, LoginDiagnosticStep(id: "s3", title: "PAT 身份验证", detail: error.localizedDescription, state: .failed)]
        }
    }

    internal func resolvedServerVersion(from probeVersion: String) -> String {
        let genericVersions: Set<String> = ["pass", "ok", "1.27+"]
        if genericVersions.contains(probeVersion),
           !health.serverVersion.isEmpty,
           health.serverVersion != "unreachable" {
            return health.serverVersion
        }
        return probeVersion
    }

    @discardableResult
    public func startLiveActivity(for run: WorkflowRun) -> Bool {
        do {
            try liveActivity.startOrUpdate(for: run)
            showToast("已启动实时活动")
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    public func syncWidgetSnapshot() {
        guard writesWidgetSnapshot else { return }
        buildAndSyncWidgetState()
    }

    public func showToast(_ message: String, tone: ToastTone? = nil) {
        statusToast = message
        statusToastTone = tone ?? ToastTone.infer(from: message)
    }

    internal static func saveProfile(_ profile: InstanceProfile, key: String, defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
    }

    private static func loadSavedProfile(key: String, defaults: UserDefaults) -> InstanceProfile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(InstanceProfile.self, from: data)
    }
}

public extension EndpointHealth {
    var sidebarVersionBadge: (label: String, tone: StatusBadge.Tone) {
        let raw = serverVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw == "未加载" {
            return ("待连接", .neutral)
        }
        if raw.caseInsensitiveCompare("unreachable") == .orderedSame {
            return ("离线", .error)
        }
        let core = raw.split(whereSeparator: { $0 == "+" || $0 == "-" }).first.map(String.init) ?? raw
        let formatted = core.first?.isNumber == true ? "v\(core)" : core
        return (String(formatted.prefix(10)), .primary)
    }
}
