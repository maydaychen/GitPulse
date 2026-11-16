#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import Foundation

public struct BuildActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var currentStepName: String
        public var completedSteps: Int
        public var totalSteps: Int
        public var elapsedSeconds: Int
        public var statusRaw: String

        public init(
            currentStepName: String,
            completedSteps: Int,
            totalSteps: Int,
            elapsedSeconds: Int,
            statusRaw: String
        ) {
            self.currentStepName = currentStepName
            self.completedSteps = completedSteps
            self.totalSteps = totalSteps
            self.elapsedSeconds = elapsedSeconds
            self.statusRaw = statusRaw
        }
    }

    public var repoFullName: String
    public var workflowName: String
    public var runNumber: Int

    public init(repoFullName: String, workflowName: String, runNumber: Int) {
        self.repoFullName = repoFullName
        self.workflowName = workflowName
        self.runNumber = runNumber
    }
}
#endif
