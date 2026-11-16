import Foundation

public enum TriageKind: String, Codable, Sendable {
    case pullRequest
    case failedRun
    case offlineRunner
}

public struct TriageItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var kind: TriageKind
    public var priority: Int
    public var repoFullName: String
    public var title: String
    public var subtitlePill: String
    public var metricText: String
    public var deepLink: String

    public init(
        id: String,
        kind: TriageKind,
        priority: Int,
        repoFullName: String,
        title: String,
        subtitlePill: String,
        metricText: String,
        deepLink: String
    ) {
        self.id = id
        self.kind = kind
        self.priority = priority
        self.repoFullName = repoFullName
        self.title = title
        self.subtitlePill = subtitlePill
        self.metricText = metricText
        self.deepLink = deepLink
    }
}

public struct HeatmapDay: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var date: Date
    public var contributions: Int

    public init(id: String, date: Date, contributions: Int) {
        self.id = id
        self.date = date
        self.contributions = contributions
    }
}

public struct ActivityEvent: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var actor: String
    public var actionLabel: String
    public var repoFullName: String
    public var refText: String
    public var timestampText: String
    public var deepLink: String

    public init(
        id: String,
        actor: String,
        actionLabel: String,
        repoFullName: String,
        refText: String,
        timestampText: String,
        deepLink: String
    ) {
        self.id = id
        self.actor = actor
        self.actionLabel = actionLabel
        self.repoFullName = repoFullName
        self.refText = refText
        self.timestampText = timestampText
        self.deepLink = deepLink
    }
}

public struct PinnedRepoSummary: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var fullName: String
    public var defaultBranch: String
    public var openPRCount: Int
    public var ciStatus: RunStatus
    public var isMirror: Bool

    public init(
        id: String,
        fullName: String,
        defaultBranch: String,
        openPRCount: Int,
        ciStatus: RunStatus,
        isMirror: Bool = false
    ) {
        self.id = id
        self.fullName = fullName
        self.defaultBranch = defaultBranch
        self.openPRCount = openPRCount
        self.ciStatus = ciStatus
        self.isMirror = isMirror
    }
}
