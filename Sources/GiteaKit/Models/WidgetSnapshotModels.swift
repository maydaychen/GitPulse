import Foundation

/// Non-sensitive endpoint and user context shared with WidgetKit extensions via App Group.
public struct WidgetConnectionContext: Codable, Sendable, Equatable {
    public var profileID: String
    public var displayName: String
    public var publicURL: String
    public var lanURL: String?
    public var activeChannel: EndpointChannel
    public var username: String
    public var isDemoMode: Bool

    public init(
        profileID: String,
        displayName: String,
        publicURL: String,
        lanURL: String? = nil,
        activeChannel: EndpointChannel = .publicProxy,
        username: String = "",
        isDemoMode: Bool = false
    ) {
        self.profileID = profileID
        self.displayName = displayName
        self.publicURL = publicURL
        self.lanURL = lanURL
        self.activeChannel = activeChannel
        self.username = username
        self.isDemoMode = isDemoMode
    }
}

public struct WidgetDashboardSnapshot: Codable, Sendable, Equatable {
    public var instanceName: String
    public var probePillText: String
    public var serverVersion: String
    public var unreadInboxCount: Int
    public var runningBuildCount: Int
    public var failedBuildCount: Int
    public var onlineRunnerCount: Int
    public var offlineRunnerCount: Int
    public var activeRunRepo: String?
    public var activeRunStep: String?
    public var heatmapDays: [HeatmapDay]
    public var triageItems: [TriageItem]
    public var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case instanceName
        case probePillText
        case serverVersion
        case unreadInboxCount
        case runningBuildCount
        case failedBuildCount
        case onlineRunnerCount
        case offlineRunnerCount
        case activeRunRepo
        case activeRunStep
        case heatmapDays
        case triageItems
        case updatedAt
    }

    public init(
        instanceName: String = "TeaPulse",
        probePillText: String,
        serverVersion: String,
        unreadInboxCount: Int,
        runningBuildCount: Int,
        failedBuildCount: Int,
        onlineRunnerCount: Int,
        offlineRunnerCount: Int,
        activeRunRepo: String? = nil,
        activeRunStep: String? = nil,
        heatmapDays: [HeatmapDay] = [],
        triageItems: [TriageItem] = [],
        updatedAt: Date = Date()
    ) {
        self.instanceName = instanceName
        self.probePillText = probePillText
        self.serverVersion = serverVersion
        self.unreadInboxCount = unreadInboxCount
        self.runningBuildCount = runningBuildCount
        self.failedBuildCount = failedBuildCount
        self.onlineRunnerCount = onlineRunnerCount
        self.offlineRunnerCount = offlineRunnerCount
        self.activeRunRepo = activeRunRepo
        self.activeRunStep = activeRunStep
        self.heatmapDays = heatmapDays
        self.triageItems = triageItems
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instanceName = try container.decodeIfPresent(String.self, forKey: .instanceName) ?? "TeaPulse"
        probePillText = try container.decode(String.self, forKey: .probePillText)
        serverVersion = try container.decode(String.self, forKey: .serverVersion)
        unreadInboxCount = try container.decode(Int.self, forKey: .unreadInboxCount)
        runningBuildCount = try container.decode(Int.self, forKey: .runningBuildCount)
        failedBuildCount = try container.decode(Int.self, forKey: .failedBuildCount)
        onlineRunnerCount = try container.decode(Int.self, forKey: .onlineRunnerCount)
        offlineRunnerCount = try container.decode(Int.self, forKey: .offlineRunnerCount)
        activeRunRepo = try container.decodeIfPresent(String.self, forKey: .activeRunRepo)
        activeRunStep = try container.decodeIfPresent(String.self, forKey: .activeRunStep)
        heatmapDays = try container.decodeIfPresent([HeatmapDay].self, forKey: .heatmapDays) ?? []
        triageItems = try container.decodeIfPresent([TriageItem].self, forKey: .triageItems) ?? []
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    /// Aggregates raw heatmap events into a dense trailing window aligned to UTC calendar days.
    public func normalizedHeatmapDays(weeks: Int = 16, referenceDate: Date = Date()) -> [HeatmapDay] {
        let clampedWeeks = max(1, weeks)
        let totalDays = clampedWeeks * 7
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let maxDataDate = heatmapDays.map(\.date).max() ?? referenceDate
        let anchor = max(referenceDate, maxDataDate)
        let endDay = calendar.startOfDay(for: anchor)
        var countsByDay: [Date: Int] = [:]
        for item in heatmapDays {
            let bucket = calendar.startOfDay(for: item.date)
            countsByDay[bucket, default: 0] += item.contributions
        }
        return (-(totalDays - 1)...0).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: endDay) ?? endDay
            return HeatmapDay(
                id: "w-hm-\(offset)",
                date: day,
                contributions: countsByDay[day, default: 0]
            )
        }
    }

    /// Total commit/contribution count over the trailing 16-week window.
    public var heatmapTotalContributions: Int {
        normalizedHeatmapDays(weeks: 16, referenceDate: updatedAt).reduce(0) { $0 + $1.contributions }
    }

    /// Current active day streak aligned with `HeatmapGridView.streakDays`.
    public var heatmapStreakDays: Int {
        var streak = 0
        for day in normalizedHeatmapDays(weeks: 16, referenceDate: updatedAt).reversed() {
            if day.contributions > 0 {
                streak += 1
            } else if streak > 0 {
                break
            }
        }
        return streak
    }

    /// Generates a sanitized preview snapshot for Widget Gallery placeholders and Demo Mode fallbacks.
    public static func makePreview(now: Date = Date()) -> WidgetDashboardSnapshot {
        let demo = DemoDataProvider.makeSnapshot()
        return WidgetDashboardSnapshot(
            instanceName: "TeaPulse",
            probePillText: demo.health.probePillText,
            serverVersion: demo.health.serverVersion,
            unreadInboxCount: demo.notifications.filter(\.unread).count,
            runningBuildCount: demo.runs.filter { $0.status == .running }.count,
            failedBuildCount: demo.runs.filter { $0.status == .failure }.count,
            onlineRunnerCount: demo.runners.filter { $0.status != .offline }.count,
            offlineRunnerCount: demo.runners.filter { $0.status == .offline }.count,
            activeRunRepo: demo.runs.first(where: { $0.status == .running })?.repoFullName,
            activeRunStep: demo.runs.first(where: { $0.status == .running })?.steps.last?.name,
            heatmapDays: Array(demo.heatmap.suffix(112)),
            triageItems: Array(demo.triage.prefix(4)),
            updatedAt: now
        )
    }
}

public struct PendingSharedRoute: Codable, Sendable, Equatable {
    public var deepLink: String
    public var sourceURL: String
    public var title: String
    public var queuedAt: Date

    public init(deepLink: String, sourceURL: String, title: String, queuedAt: Date = Date()) {
        self.deepLink = deepLink
        self.sourceURL = sourceURL
        self.title = title
        self.queuedAt = queuedAt
    }
}
