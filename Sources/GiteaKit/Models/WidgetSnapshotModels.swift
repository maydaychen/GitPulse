import Foundation

public struct WidgetDashboardSnapshot: Codable, Sendable, Equatable {
    public var probePillText: String
    public var serverVersion: String
    public var unreadInboxCount: Int
    public var runningBuildCount: Int
    public var failedBuildCount: Int
    public var onlineRunnerCount: Int
    public var offlineRunnerCount: Int
    public var activeRunRepo: String?
    public var activeRunStep: String?
    public var updatedAt: Date

    public init(
        probePillText: String,
        serverVersion: String,
        unreadInboxCount: Int,
        runningBuildCount: Int,
        failedBuildCount: Int,
        onlineRunnerCount: Int,
        offlineRunnerCount: Int,
        activeRunRepo: String? = nil,
        activeRunStep: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.probePillText = probePillText
        self.serverVersion = serverVersion
        self.unreadInboxCount = unreadInboxCount
        self.runningBuildCount = runningBuildCount
        self.failedBuildCount = failedBuildCount
        self.onlineRunnerCount = onlineRunnerCount
        self.offlineRunnerCount = offlineRunnerCount
        self.activeRunRepo = activeRunRepo
        self.activeRunStep = activeRunStep
        self.updatedAt = updatedAt
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
