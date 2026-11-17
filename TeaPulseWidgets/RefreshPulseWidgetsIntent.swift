import AppIntents
import Foundation
import GiteaKit
import WidgetKit

/// Interactive AppIntent triggered by the widget header refresh button to re-fetch live telemetry.
public struct RefreshPulseWidgetsIntent: AppIntent {
    public static var title: LocalizedStringResource {
        "刷新 TeaPulse 小组件"
    }

    public static var description: IntentDescription {
        IntentDescription("立即从 Gitea 实例拉取最新构建、待审队列与提交热力。")
    }

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        _ = await WidgetLiveRefresher.refreshFromSharedContext(forceDemoTimestampUpdate: true)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

public struct PulseWidgetEntry: TimelineEntry {
    public let date: Date
    public let snapshot: WidgetDashboardSnapshot?

    public init(date: Date, snapshot: WidgetDashboardSnapshot?) {
        self.date = date
        self.snapshot = snapshot
    }
}

private final class TimelineCompletionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var handler: ((Timeline<PulseWidgetEntry>) -> Void)?

    init(_ handler: @escaping (Timeline<PulseWidgetEntry>) -> Void) {
        self.handler = handler
    }

    func complete(with timeline: Timeline<PulseWidgetEntry>) {
        let taken = lock.withLock {
            let current = handler
            handler = nil
            return current
        }
        taken?(timeline)
    }
}

public struct PulseWidgetProvider: TimelineProvider {
    public init() {}

    public func placeholder(in context: Context) -> PulseWidgetEntry {
        PulseWidgetEntry(date: Date(), snapshot: WidgetDashboardSnapshot.makePreview())
    }

    public func getSnapshot(in context: Context, completion: @escaping (PulseWidgetEntry) -> Void) {
        let snapshot = AppGroupBridge.loadWidgetSnapshot()
            ?? (context.isPreview ? WidgetDashboardSnapshot.makePreview() : nil)
        completion(PulseWidgetEntry(date: Date(), snapshot: snapshot))
    }

    public func getTimeline(in context: Context, completion: @escaping (Timeline<PulseWidgetEntry>) -> Void) {
        let cached = AppGroupBridge.loadWidgetSnapshot()
        let box = TimelineCompletionBox(completion)

        Task {
            let now = Date()
            let resolved = await WidgetLiveRefresher.refreshFromSharedContext(now: now) ?? cached
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
            let entry = PulseWidgetEntry(date: now, snapshot: resolved)
            box.complete(with: Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}
