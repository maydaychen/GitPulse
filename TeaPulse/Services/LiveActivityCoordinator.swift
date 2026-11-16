import Foundation
import GiteaKit
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

@MainActor
public protocol LiveActivityCoordinating {
    func startOrUpdate(for run: WorkflowRun) throws
}

public enum LiveActivityError: LocalizedError {
    case disabled
    case unsupported

    public var errorDescription: String? {
        switch self {
        case .disabled: return "实时活动已关闭，请在系统设置中允许 TeaPulse 使用实时活动"
        case .unsupported: return "当前平台不支持实时活动"
        }
    }
}

@MainActor
public final class LiveActivityCoordinator: LiveActivityCoordinating {
    #if canImport(ActivityKit) && os(iOS)
    private var activeActivity: Activity<BuildActivityAttributes>?
    #endif

    public init() {}

    public func startOrUpdate(for run: WorkflowRun) throws {
        #if canImport(ActivityKit) && os(iOS)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw LiveActivityError.disabled }
        let completed = run.steps.filter { $0.status == .success }.count
        let total = max(run.steps.count, 1)
        let activeStep = run.steps.first { $0.status == .running }?.name
            ?? run.steps.last?.name
            ?? run.workflowName
        let state = BuildActivityAttributes.ContentState(
            currentStepName: activeStep,
            completedSteps: completed,
            totalSteps: total,
            elapsedSeconds: run.durationSeconds,
            statusRaw: run.status.badgeLabel
        )

        if let current = activeActivity, current.attributes.runNumber == run.runNumber {
            let activityID = current.id
            Task.detached {
                if let target = Activity<BuildActivityAttributes>.activities.first(where: { $0.id == activityID }) {
                    await target.update(ActivityContent(state: state, staleDate: nil))
                }
            }
            return
        }

        let attrs = BuildActivityAttributes(
            repoFullName: run.repoFullName,
            workflowName: run.workflowName,
            runNumber: run.runNumber
        )
        activeActivity = try Activity.request(
            attributes: attrs,
            content: ActivityContent(state: state, staleDate: nil)
        )
        #else
        throw LiveActivityError.unsupported
        #endif
    }

    public func endAll() {
        #if canImport(ActivityKit) && os(iOS)
        guard let current = activeActivity else { return }
        let activityID = current.id
        Task.detached {
            if let target = Activity<BuildActivityAttributes>.activities.first(where: { $0.id == activityID }) {
                await target.end(nil, dismissalPolicy: .immediate)
            }
        }
        activeActivity = nil
        #endif
    }
}
