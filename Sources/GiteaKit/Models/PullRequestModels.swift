import Foundation

public enum PRState: String, Codable, Sendable {
    case open
    case merged
    case closed
}

public enum PRReviewDecision: String, Codable, Sendable, CaseIterable {
    case approve = "APPROVED"
    case comment = "COMMENT"
    case requestChanges = "REQUEST_CHANGES"

    public var label: String {
        switch self {
        case .approve:
            return "批准"
        case .comment:
            return "仅评论"
        case .requestChanges:
            return "请求修改"
        }
    }
}

public enum PRMergeStrategy: String, Codable, Sendable, CaseIterable {
    case squash
    case merge
    case rebase

    public var label: String {
        switch self {
        case .squash:
            return "压缩合并"
        case .merge:
            return "普通合并"
        case .rebase:
            return "变基合并"
        }
    }
}

public struct CICheckItem: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var name: String
    public var status: RunStatus
    public var durationText: String
    public var deepLink: String

    public init(id: String, name: String, status: RunStatus, durationText: String, deepLink: String) {
        self.id = id
        self.name = name
        self.status = status
        self.durationText = durationText
        self.deepLink = deepLink
    }
}

public enum DiffSide: String, Codable, Sendable {
    case old
    case new
}

public struct PRTimelineComment: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var author: String
    public var body: String
    public var filePath: String?
    public var lineNumber: Int?
    public var side: DiffSide
    public var timestampText: String

    public init(
        id: String,
        author: String,
        body: String,
        filePath: String? = nil,
        lineNumber: Int? = nil,
        side: DiffSide = .new,
        timestampText: String
    ) {
        self.id = id
        self.author = author
        self.body = body
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.side = side
        self.timestampText = timestampText
    }
}

public enum DiffLineKind: String, Codable, Sendable {
    case context
    case addition
    case deletion
}

public struct DiffLine: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var kind: DiffLineKind
    public var oldLineNumber: Int?
    public var newLineNumber: Int?
    public var content: String

    public init(
        id: String,
        kind: DiffLineKind,
        oldLineNumber: Int?,
        newLineNumber: Int?,
        content: String
    ) {
        self.id = id
        self.kind = kind
        self.oldLineNumber = oldLineNumber
        self.newLineNumber = newLineNumber
        self.content = content
    }
}

public struct SplitDiffRow: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var left: DiffLine?
    public var right: DiffLine?

    public init(id: String, left: DiffLine?, right: DiffLine?) {
        self.id = id
        self.left = left
        self.right = right
    }
}

public struct DiffHunk: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var header: String
    public var lines: [DiffLine]
    public var splitRows: [SplitDiffRow]

    public init(id: String, header: String, lines: [DiffLine], splitRows: [SplitDiffRow]) {
        self.id = id
        self.header = header
        self.lines = lines
        self.splitRows = splitRows
    }
}

public struct DiffFilePatch: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var path: String
    public var status: String
    public var additions: Int
    public var deletions: Int
    public var hunks: [DiffHunk]

    public init(
        id: String,
        path: String,
        status: String,
        additions: Int,
        deletions: Int,
        hunks: [DiffHunk]
    ) {
        self.id = id
        self.path = path
        self.status = status
        self.additions = additions
        self.deletions = deletions
        self.hunks = hunks
    }
}

public struct InlineReviewDraft: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var filePath: String
    public var lineNumber: Int
    public var side: DiffSide
    public var body: String

    public init(id: String = UUID().uuidString, filePath: String, lineNumber: Int, side: DiffSide = .new, body: String) {
        self.id = id
        self.filePath = filePath
        self.lineNumber = lineNumber
        self.side = side
        self.body = body
    }
}

public struct PullRequestDetail: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var number: Int
    public var repoFullName: String
    public var title: String
    public var author: String
    public var headBranch: String
    public var headSHA: String?
    public var baseBranch: String
    public var state: PRState
    public var mergeable: Bool
    public var additions: Int
    public var deletions: Int
    public var stackPosition: Int?
    public var stackTotal: Int?
    public var checks: [CICheckItem]
    public var comments: [PRTimelineComment]
    public var files: [DiffFilePatch]

    public init(
        id: String,
        number: Int,
        repoFullName: String,
        title: String,
        author: String,
        headBranch: String,
        headSHA: String? = nil,
        baseBranch: String,
        state: PRState,
        mergeable: Bool,
        additions: Int,
        deletions: Int,
        stackPosition: Int? = nil,
        stackTotal: Int? = nil,
        checks: [CICheckItem] = [],
        comments: [PRTimelineComment] = [],
        files: [DiffFilePatch] = []
    ) {
        self.id = id
        self.number = number
        self.repoFullName = repoFullName
        self.title = title
        self.author = author
        self.headBranch = headBranch
        self.headSHA = headSHA
        self.baseBranch = baseBranch
        self.state = state
        self.mergeable = mergeable
        self.additions = additions
        self.deletions = deletions
        self.stackPosition = stackPosition
        self.stackTotal = stackTotal
        self.checks = checks
        self.comments = comments
        self.files = files
    }

    public var branchRouteLabel: String {
        "\(headBranch) -> \(baseBranch)"
    }
}
