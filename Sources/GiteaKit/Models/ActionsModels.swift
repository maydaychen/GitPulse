import Foundation

public enum RunStatus: String, Codable, Sendable, CaseIterable {
    case running
    case waitingApproval
    case success
    case failure

    public var badgeLabel: String {
        switch self {
        case .running:
            return "运行中"
        case .waitingApproval:
            return "待审批"
        case .success:
            return "通过"
        case .failure:
            return "失败"
        }
    }
}

public enum ANSISeverity: String, Codable, Sendable {
    case normal
    case info
    case success
    case warning
    case error
    case muted
}

public struct ANSITerminalLine: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var lineNumber: Int
    public var text: String
    public var severity: ANSISeverity

    public init(id: String, lineNumber: Int, text: String, severity: ANSISeverity) {
        self.id = id
        self.lineNumber = lineNumber
        self.text = text
        self.severity = severity
    }
}

public struct WorkflowStepLog: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var number: Int
    public var name: String
    public var status: RunStatus
    public var durationSeconds: Int
    public var isExpanded: Bool
    public var firstErrorLineIndex: Int?
    public var lines: [ANSITerminalLine]

    public init(
        id: String,
        number: Int,
        name: String,
        status: RunStatus,
        durationSeconds: Int,
        isExpanded: Bool,
        firstErrorLineIndex: Int? = nil,
        lines: [ANSITerminalLine]
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.status = status
        self.durationSeconds = durationSeconds
        self.isExpanded = isExpanded
        self.firstErrorLineIndex = firstErrorLineIndex
        self.lines = lines
    }
}

public struct WorkflowDispatchInput: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var key: String
    public var defaultValue: String
    public var options: [String]

    public init(id: String, key: String, defaultValue: String, options: [String] = []) {
        self.id = id
        self.key = key
        self.defaultValue = defaultValue
        self.options = options
    }
}

public struct WorkflowRun: Codable, Sendable, Identifiable, Equatable, Hashable {
    public let id: String
    public var runNumber: Int
    public var jobID: Int64
    public var repoFullName: String
    public var workflowName: String
    public var workflowFile: String
    public var branch: String
    public var commitSHA: String
    public var status: RunStatus
    public var runnerName: String
    public var durationSeconds: Int
    public var inputs: [WorkflowDispatchInput]
    public var steps: [WorkflowStepLog]
    public var artifacts: [String]

    public init(
        id: String,
        runNumber: Int,
        jobID: Int64,
        repoFullName: String,
        workflowName: String,
        workflowFile: String,
        branch: String,
        commitSHA: String,
        status: RunStatus,
        runnerName: String,
        durationSeconds: Int,
        inputs: [WorkflowDispatchInput] = [],
        steps: [WorkflowStepLog] = [],
        artifacts: [String] = []
    ) {
        self.id = id
        self.runNumber = runNumber
        self.jobID = jobID
        self.repoFullName = repoFullName
        self.workflowName = workflowName
        self.workflowFile = workflowFile
        self.branch = branch
        self.commitSHA = commitSHA
        self.status = status
        self.runnerName = runnerName
        self.durationSeconds = durationSeconds
        self.inputs = inputs
        self.steps = steps
        self.artifacts = artifacts
    }

    public var durationText: String {
        let minutes = durationSeconds / 60
        let seconds = durationSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

public enum RunnerOnlineStatus: String, Codable, Sendable {
    case online
    case busy
    case offline

    public var badgeLabel: String {
        switch self {
        case .online:
            return "在线"
        case .busy:
            return "执行中"
        case .offline:
            return "离线"
        }
    }
}

public struct RunnerNode: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var name: String
    public var hostLabel: String
    public var status: RunnerOnlineStatus
    public var labels: [String]
    public var activeJobTitle: String?
    public var version: String

    public init(
        id: String,
        name: String,
        hostLabel: String,
        status: RunnerOnlineStatus,
        labels: [String],
        activeJobTitle: String? = nil,
        version: String
    ) {
        self.id = id
        self.name = name
        self.hostLabel = hostLabel
        self.status = status
        self.labels = labels
        self.activeJobTitle = activeJobTitle
        self.version = version
    }
}
