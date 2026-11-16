import Foundation

public enum NotificationCategory: String, Codable, Sendable, CaseIterable {
    case pending = "待处理"
    case mention = "@提及与评审"
    case ciAlert = "CI 告警"
    case archived = "已归档"
}

public struct NotificationThread: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var category: NotificationCategory
    public var repoFullName: String
    public var subjectTitle: String
    public var subjectType: String
    public var unread: Bool
    public var isMutedRepo: Bool
    public var updatedAtText: String
    public var deepLink: String

    public init(
        id: String,
        category: NotificationCategory,
        repoFullName: String,
        subjectTitle: String,
        subjectType: String,
        unread: Bool,
        isMutedRepo: Bool = false,
        updatedAtText: String,
        deepLink: String
    ) {
        self.id = id
        self.category = category
        self.repoFullName = repoFullName
        self.subjectTitle = subjectTitle
        self.subjectType = subjectType
        self.unread = unread
        self.isMutedRepo = isMutedRepo
        self.updatedAtText = updatedAtText
        self.deepLink = deepLink
    }
}
