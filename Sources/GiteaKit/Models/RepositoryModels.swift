import Foundation

public enum RepoScope: String, Codable, Sendable, CaseIterable {
    case all = "全部"
    case personal = "个人"
    case org = "组织"
    case mirror = "镜像"
    case starred = "星标"
}

public struct OrganizationSummary: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var username: String
    public var fullName: String

    public init(id: String, username: String, fullName: String = "") {
        self.id = id
        self.username = username
        self.fullName = fullName
    }
}

public struct RepositorySummary: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var owner: String
    public var name: String
    public var fullName: String
    public var scope: RepoScope
    public var isOrganizationOwned: Bool
    public var isStarred: Bool
    public var isMirror: Bool
    public var mirrorInterval: String?
    public var lastMirrorSyncText: String?
    public var defaultBranch: String
    public var stars: Int
    public var openPRCount: Int
    public var openIssueCount: Int
    public var updatedAtText: String
    public var cloneURL: String
    public var sshURL: String
    public var readmeMarkdown: String

    public init(
        id: String,
        owner: String,
        name: String,
        fullName: String,
        scope: RepoScope,
        isOrganizationOwned: Bool? = nil,
        isStarred: Bool,
        isMirror: Bool,
        mirrorInterval: String? = nil,
        lastMirrorSyncText: String? = nil,
        defaultBranch: String,
        stars: Int,
        openPRCount: Int,
        openIssueCount: Int,
        updatedAtText: String,
        cloneURL: String,
        sshURL: String,
        readmeMarkdown: String
    ) {
        self.id = id
        self.owner = owner
        self.name = name
        self.fullName = fullName
        self.scope = scope
        self.isOrganizationOwned = isOrganizationOwned ?? (scope == .org)
        self.isStarred = isStarred
        self.isMirror = isMirror
        self.mirrorInterval = mirrorInterval
        self.lastMirrorSyncText = lastMirrorSyncText
        self.defaultBranch = defaultBranch
        self.stars = stars
        self.openPRCount = openPRCount
        self.openIssueCount = openIssueCount
        self.updatedAtText = updatedAtText
        self.cloneURL = cloneURL
        self.sshURL = sshURL
        self.readmeMarkdown = readmeMarkdown
    }
}

public struct RepoFileEntry: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var name: String
    public var path: String
    public var isDirectory: Bool
    public var sizeBytes: Int
    public var sha: String
    public var content: String?

    public init(
        id: String,
        name: String,
        path: String,
        isDirectory: Bool,
        sizeBytes: Int,
        sha: String,
        content: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.sizeBytes = sizeBytes
        self.sha = sha
        self.content = content
    }

    public var formattedSize: String {
        if sizeBytes < 1024 {
            return "\(sizeBytes) B"
        }
        if sizeBytes < 1_048_576 {
            return String(format: "%.1f KB", Double(sizeBytes) / 1024.0)
        }
        return String(format: "%.1f MB", Double(sizeBytes) / 1_048_576.0)
    }
}

public struct RepoBranchItem: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var name: String
    public var commitSHA: String
    public var isDefault: Bool
    public var isTag: Bool

    public init(
        id: String,
        name: String,
        commitSHA: String = "",
        isDefault: Bool = false,
        isTag: Bool = false
    ) {
        self.id = id
        self.name = name
        self.commitSHA = commitSHA
        self.isDefault = isDefault
        self.isTag = isTag
    }
}

public struct RepoCommitItem: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var sha: String
    public var shortSHA: String
    public var title: String
    public var message: String
    public var author: String
    public var timestampText: String
    public var filesChangedCount: Int

    public init(
        id: String,
        sha: String,
        shortSHA: String,
        title: String,
        message: String,
        author: String,
        timestampText: String,
        filesChangedCount: Int = 0
    ) {
        self.id = id
        self.sha = sha
        self.shortSHA = shortSHA
        self.title = title
        self.message = message
        self.author = author
        self.timestampText = timestampText
        self.filesChangedCount = filesChangedCount
    }
}

public struct IssueItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var number: Int
    public var title: String
    public var state: String
    public var author: String
    public var labels: [String]
    public var blockedByNumbers: [Int]
    public var updatedAtText: String

    public init(
        id: String,
        number: Int,
        title: String,
        state: String,
        author: String,
        labels: [String] = [],
        blockedByNumbers: [Int] = [],
        updatedAtText: String
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.state = state
        self.author = author
        self.labels = labels
        self.blockedByNumbers = blockedByNumbers
        self.updatedAtText = updatedAtText
    }
}

public struct KanbanCard: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var column: String
    public var title: String
    public var refNumber: Int
    public var assignee: String

    public init(id: String, column: String, title: String, refNumber: Int, assignee: String) {
        self.id = id
        self.column = column
        self.title = title
        self.refNumber = refNumber
        self.assignee = assignee
    }
}

public struct ReleaseItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var tagName: String
    public var title: String
    public var publishedAtText: String
    public var assetNames: [String]
    public var isPrerelease: Bool

    public init(
        id: String,
        tagName: String,
        title: String,
        publishedAtText: String,
        assetNames: [String],
        isPrerelease: Bool = false
    ) {
        self.id = id
        self.tagName = tagName
        self.title = title
        self.publishedAtText = publishedAtText
        self.assetNames = assetNames
        self.isPrerelease = isPrerelease
    }
}

public struct RepoSecretItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var updatedAtText: String

    public init(id: String, name: String, updatedAtText: String) {
        self.id = id
        self.name = name
        self.updatedAtText = updatedAtText
    }
}

public struct RepoVariableItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var value: String

    public init(id: String, name: String, value: String) {
        self.id = id
        self.name = name
        self.value = value
    }
}

public struct WebhookDelivery: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var statusCode: Int
    public var deliveredAtText: String
    public var eventName: String
    public var responseSummary: String

    public init(
        id: String,
        statusCode: Int,
        deliveredAtText: String,
        eventName: String,
        responseSummary: String
    ) {
        self.id = id
        self.statusCode = statusCode
        self.deliveredAtText = deliveredAtText
        self.eventName = eventName
        self.responseSummary = responseSummary
    }
}

public struct WebhookConfig: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var numericID: Int
    public var targetURL: String
    public var events: [String]
    public var isActive: Bool
    public var lastStatusCode: Int
    public var deliveries: [WebhookDelivery]

    public init(
        id: String,
        numericID: Int,
        targetURL: String,
        events: [String],
        isActive: Bool,
        lastStatusCode: Int,
        deliveries: [WebhookDelivery]
    ) {
        self.id = id
        self.numericID = numericID
        self.targetURL = targetURL
        self.events = events
        self.isActive = isActive
        self.lastStatusCode = lastStatusCode
        self.deliveries = deliveries
    }
}
