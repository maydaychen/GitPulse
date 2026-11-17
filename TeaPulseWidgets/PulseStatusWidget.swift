import GiteaKit
import SwiftUI
import WidgetKit

struct PulseStatusWidgetEntryView: View {
    var entry: PulseWidgetProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        #if os(iOS)
        case .accessoryCircular:
            circularAccessoryView
                .containerBackground(for: .widget) {
                    AccessoryWidgetBackground()
                }
        case .accessoryRectangular:
            rectangularAccessoryView
                .containerBackground(for: .widget) {
                    Color.clear
                }
        #endif
        default:
            desktopBody
                .padding(TeaPulseSpacing.sm)
                .containerBackground(TeaPulseTheme.surface, for: .widget)
                .widgetURL(URL(string: "teapulse://ops/runners"))
        }
    }

    private var desktopBody: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
            HStack(spacing: TeaPulseSpacing.xs) {
                Circle()
                    .fill(WidgetFormatters.statusColor(for: entry.snapshot))
                    .frame(width: 8, height: 8)
                Text(entry.snapshot?.instanceName ?? "TeaPulse")
                    .font(TeaPulseTypography.labelMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .lineLimit(1)
                Spacer(minLength: TeaPulseSpacing.xs)
                if family != .systemSmall {
                    Text(entry.snapshot?.probePillText ?? "待同步")
                        .font(TeaPulseTypography.codeSm)
                        .monospacedDigit()
                        .foregroundStyle(TeaPulseTheme.secondary)
                        .lineLimit(1)
                }
                WidgetRefreshButton()
            }

            if let snapshot = entry.snapshot {
                metricsRow(snapshot: snapshot)

                if family == .systemSmall {
                    Spacer(minLength: 0)
                    Text(snapshot.probePillText)
                        .font(TeaPulseTypography.codeSm)
                        .monospacedDigit()
                        .foregroundStyle(TeaPulseTheme.secondary)
                        .lineLimit(1)
                } else {
                    activeSummaryLine(snapshot: snapshot)
                }

                if family == .systemLarge {
                    Rectangle()
                        .fill(TeaPulseTheme.cardBorder)
                        .frame(height: 1)
                    largePrioritySection(snapshot: snapshot)
                }
            } else {
                Spacer(minLength: 0)
                Text("打开 TeaPulse 同步实例状态")
                    .font(TeaPulseTypography.bodySm)
                    .foregroundStyle(TeaPulseTheme.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private func metricsRow(snapshot: WidgetDashboardSnapshot) -> some View {
        HStack(spacing: TeaPulseSpacing.md) {
            WidgetMetricBlock(label: "运行", value: "\(snapshot.runningBuildCount)", color: TeaPulseTheme.warning)
            WidgetMetricBlock(label: "失败", value: "\(snapshot.failedBuildCount)", color: TeaPulseTheme.error)
            WidgetMetricBlock(label: "未读", value: "\(snapshot.unreadInboxCount)", color: TeaPulseTheme.primary)
            if family != .systemSmall {
                WidgetMetricBlock(label: "节点", value: "\(snapshot.onlineRunnerCount)", color: TeaPulseTheme.tertiary)
            }
        }
    }

    @ViewBuilder
    private func activeSummaryLine(snapshot: WidgetDashboardSnapshot) -> some View {
        if let repo = snapshot.activeRunRepo {
            Text("\(repo) · \(snapshot.activeRunStep ?? "运行中")")
                .font(TeaPulseTypography.codeSm)
                .foregroundStyle(TeaPulseTheme.secondary)
                .lineLimit(1)
        } else if let topItem = snapshot.triageItems.first {
            Text("\(topItem.repoFullName) · \(topItem.title)")
                .font(TeaPulseTypography.codeSm)
                .foregroundStyle(TeaPulseTheme.secondary)
                .lineLimit(1)
        } else {
            Text("Gitea \(snapshot.serverVersion) · 同步于 \(WidgetFormatters.shortTime(snapshot.updatedAt))")
                .font(TeaPulseTypography.codeSm)
                .monospacedDigit()
                .foregroundStyle(TeaPulseTheme.secondary)
                .lineLimit(1)
        }
    }

    private func largePrioritySection(snapshot: WidgetDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
            HStack {
                Text("优先处理队列")
                    .font(TeaPulseTypography.labelMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                Spacer()
                Text("同步 \(WidgetFormatters.shortTime(snapshot.updatedAt))")
                    .font(TeaPulseTypography.codeSm)
                    .monospacedDigit()
                    .foregroundStyle(TeaPulseTheme.secondary)
            }

            if snapshot.triageItems.isEmpty {
                Spacer(minLength: 0)
                Text("当前无待审 PR 或失败构建告警")
                    .font(TeaPulseTypography.bodySm)
                    .foregroundStyle(TeaPulseTheme.secondary)
                Spacer(minLength: 0)
            } else {
                ForEach(snapshot.triageItems.prefix(4)) { item in
                    let targetURL = URL(string: item.deepLink) ?? URL(string: "teapulse://pulse")!
                    Link(destination: targetURL) {
                        triageRow(item)
                    }
                }
            }
        }
    }

    private func triageRow(_ item: TriageItem) -> some View {
        HStack(spacing: TeaPulseSpacing.sm) {
            WidgetTriageIcon(kind: item.kind)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(TeaPulseTypography.bodySm)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .lineLimit(1)
                Text("\(item.repoFullName) · \(item.subtitlePill)")
                    .font(TeaPulseTypography.codeSm)
                    .foregroundStyle(TeaPulseTheme.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: TeaPulseSpacing.xs)

            Text(item.metricText)
                .font(TeaPulseTypography.codeSm)
                .monospacedDigit()
                .foregroundStyle(TeaPulseTheme.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, TeaPulseSpacing.xs)
                .padding(.vertical, 2)
                .background(TeaPulseTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
        }
        .padding(.vertical, 3)
    }

    #if os(iOS)
    private var circularAccessoryView: some View {
        let failed = entry.snapshot?.failedBuildCount ?? 0
        let running = entry.snapshot?.runningBuildCount ?? 0
        let badgeValue = failed > 0 ? failed : (running > 0 ? running : (entry.snapshot?.unreadInboxCount ?? 0))

        return ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: failed > 0 ? "exclamationmark.triangle.fill" : "waveform.path.ecg")
                    .font(TeaPulseTypography.labelMd)
                Text("\(badgeValue)")
                    .font(TeaPulseTypography.headlineMd)
                    .monospacedDigit()
            }
        }
        .widgetURL(URL(string: "teapulse://pulse"))
    }

    private var rectangularAccessoryView: some View {
        let snapshot = entry.snapshot

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: TeaPulseSpacing.xs) {
                Image(systemName: "waveform.path.ecg")
                Text(snapshot?.instanceName ?? "TeaPulse")
                    .font(TeaPulseTypography.labelMd)
                    .lineLimit(1)
                Spacer()
                if let snapshot {
                    Text(snapshot.probePillText)
                        .font(TeaPulseTypography.codeSm)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }

            if let snapshot {
                Text("运行 \(snapshot.runningBuildCount) · 失败 \(snapshot.failedBuildCount) · 未读 \(snapshot.unreadInboxCount)")
                    .font(TeaPulseTypography.codeSm)
                    .monospacedDigit()
                    .lineLimit(1)
                Text(snapshot.activeRunRepo ?? snapshot.triageItems.first?.title ?? "节点在线 \(snapshot.onlineRunnerCount)")
                    .font(TeaPulseTypography.labelMd)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("打开 TeaPulse 同步状态")
                    .font(TeaPulseTypography.labelMd)
                    .foregroundStyle(.secondary)
            }
        }
        .widgetURL(URL(string: "teapulse://ops/runners"))
    }
    #endif
}

public struct PulseStatusWidget: Widget {
    public let kind = "PulseStatusWidget"

    public init() {}

    private var supportedWidgetFamilies: [WidgetFamily] {
        #if os(iOS)
        return [.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular]
        #else
        return [.systemSmall, .systemMedium, .systemLarge]
        #endif
    }

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseWidgetProvider()) { entry in
            PulseStatusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TeaPulse 实例状态")
        .description("实时查看构建、未读通知、优先队列与执行节点在线状态，支持一键刷新与锁屏组件。")
        .supportedFamilies(supportedWidgetFamilies)
    }
}
