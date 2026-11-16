import WidgetKit
import SwiftUI
import GiteaKit

struct PulseWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDashboardSnapshot?
}

struct PulseWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PulseWidgetEntry {
        PulseWidgetEntry(date: Date(), snapshot: previewSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (PulseWidgetEntry) -> Void) {
        let snapshot = context.isPreview ? previewSnapshot() : AppGroupBridge.loadWidgetSnapshot()
        completion(PulseWidgetEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PulseWidgetEntry>) -> Void) {
        let entry = PulseWidgetEntry(date: Date(), snapshot: AppGroupBridge.loadWidgetSnapshot())
        let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private func previewSnapshot() -> WidgetDashboardSnapshot {
        WidgetDashboardSnapshot(
            probePillText: "TLS :8443 · 22ms",
            serverVersion: "1.27.3",
            unreadInboxCount: 3,
            runningBuildCount: 1,
            failedBuildCount: 1,
            onlineRunnerCount: 2,
            offlineRunnerCount: 1,
            activeRunRepo: "alex/teapulse-core",
            activeRunStep: "iOS 26.5 Simulator Test"
        )
    }
}

struct PulseStatusWidgetEntryView: View {
    var entry: PulseWidgetProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
            HStack(spacing: TeaPulseSpacing.xs) {
                Circle()
                    .fill(TeaPulseTheme.primary)
                    .frame(width: 8, height: 8)
                Text("TeaPulse")
                    .font(TeaPulseTypography.labelMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                Spacer()
                Text(entry.snapshot?.probePillText ?? "待同步")
                    .font(TeaPulseTypography.codeSm)
                    .monospacedDigit()
                    .foregroundStyle(TeaPulseTheme.secondary)
                    .lineLimit(1)
            }

            if let snapshot = entry.snapshot {
                HStack(spacing: TeaPulseSpacing.md) {
                    metricBlock("运行", "\(snapshot.runningBuildCount)", TeaPulseTheme.warning)
                    metricBlock("失败", "\(snapshot.failedBuildCount)", TeaPulseTheme.error)
                    metricBlock("未读", "\(snapshot.unreadInboxCount)", TeaPulseTheme.primary)
                    if family != .systemSmall {
                        metricBlock("节点", "\(snapshot.onlineRunnerCount)", TeaPulseTheme.tertiary)
                    }
                }
                if family != .systemSmall, let repo = snapshot.activeRunRepo {
                    Text("\(repo) · \(snapshot.activeRunStep ?? "运行中")")
                        .font(TeaPulseTypography.codeSm)
                        .foregroundStyle(TeaPulseTheme.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("打开 TeaPulse 同步状态")
                    .font(TeaPulseTypography.bodySm)
                    .foregroundStyle(TeaPulseTheme.secondary)
            }
        }
        .padding(TeaPulseSpacing.sm)
        .containerBackground(TeaPulseTheme.surface, for: .widget)
        .widgetURL(URL(string: "teapulse://ops/runners"))
    }

    private func metricBlock(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(TeaPulseTypography.headlineMd)
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(TeaPulseTypography.labelMd)
                .foregroundStyle(TeaPulseTheme.secondary)
        }
    }
}

public struct PulseStatusWidget: Widget {
    public let kind = "PulseStatusWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseWidgetProvider()) { entry in
            PulseStatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TeaPulse 实例状态")
        .description("实时查看构建、未读通知与执行节点在线数。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
