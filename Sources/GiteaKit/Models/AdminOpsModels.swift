import Foundation

public struct AdminOverviewStats: Codable, Sendable, Equatable {
    public var serverVersion: String
    public var totalUsers: Int
    public var totalRepos: Int
    public var activeRunners: Int
    public var offlineRunners: Int
    public var packageCount: Int

    public init(
        serverVersion: String,
        totalUsers: Int,
        totalRepos: Int,
        activeRunners: Int,
        offlineRunners: Int,
        packageCount: Int
    ) {
        self.serverVersion = serverVersion
        self.totalUsers = totalUsers
        self.totalRepos = totalRepos
        self.activeRunners = activeRunners
        self.offlineRunners = offlineRunners
        self.packageCount = packageCount
    }
}

public struct CronTaskItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var schedule: String
    public var nextRunText: String
    public var lastRunText: String
    public var execTimes: Int
    public var isDestructive: Bool

    public init(
        id: String,
        name: String,
        schedule: String,
        nextRunText: String,
        lastRunText: String,
        execTimes: Int,
        isDestructive: Bool = false
    ) {
        self.id = id
        self.name = name
        self.schedule = schedule
        self.nextRunText = nextRunText
        self.lastRunText = lastRunText
        self.execTimes = execTimes
        self.isDestructive = isDestructive
    }
}

public struct AdminUserItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var login: String
    public var email: String
    public var isAdmin: Bool
    public var isRestricted: Bool
    public var prohibitLogin: Bool
    public var repoCount: Int

    public init(
        id: String,
        login: String,
        email: String,
        isAdmin: Bool,
        isRestricted: Bool,
        prohibitLogin: Bool,
        repoCount: Int
    ) {
        self.id = id
        self.login = login
        self.email = email
        self.isAdmin = isAdmin
        self.isRestricted = isRestricted
        self.prohibitLogin = prohibitLogin
        self.repoCount = repoCount
    }
}

public struct PackageArtifactItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var owner: String
    public var type: String
    public var name: String
    public var version: String
    public var sizeLabel: String

    public init(
        id: String,
        owner: String,
        type: String,
        name: String,
        version: String,
        sizeLabel: String
    ) {
        self.id = id
        self.owner = owner
        self.type = type
        self.name = name
        self.version = version
        self.sizeLabel = sizeLabel
    }
}
