import GiteaKit
import SwiftUI
import WidgetKit

struct CommitHeatmapWidgetEntryView: View {
    var entry: PulseWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                if family == .systemSmall {
                    smallLayout(snapshot: snapshot)
                } else {
                    mediumLayout(snapshot: snapshot)
                }
            } else {
                emptyLayout
            }
        }
        .padding(TeaPulseSpacing.sm)
        .containerBackground(TeaPulseTheme.surface, for: .widget)
        .widgetURL(URL(string: "teapulse://pulse"))
    }

    private func smallLayout(snapshot: WidgetDashboardSnapshot) -> some View {
        let days = snapshot.normalizedHeatmapDays(weeks: 10, referenceDate: entry.date)
        let total = snapshot.heatmapTotalContributions
        let streak = snapshot.heatmapStreakDays

        return VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
            HStack(spacing: TeaPulseSpacing.xs) {
                Circle()
                    .fill(TeaPulseTheme.primary)
                    .frame(width: 7, height: 7)
                Text("\(total) 提交")
                    .font(TeaPulseTypography.labelMd)
                    .monospacedDigit()
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .lineLimit(1)
                if streak > 0 {
                    Text("\(streak)d")
                        .font(TeaPulseTypography.codeSm)
                        .monospacedDigit()
                        .foregroundStyle(TeaPulseTheme.primary)
                        .lineLimit(1)
                }
                Spacer(minLength: TeaPulseSpacing.xs)
                WidgetRefreshButton()
            }

            heatmapGrid(days: days, weekCount: 10, spacing: 3)
        }
    }

    private func mediumLayout(snapshot: WidgetDashboardSnapshot) -> some View {
        let days = snapshot.normalizedHeatmapDays(weeks: 16, referenceDate: entry.date)
        let total = snapshot.heatmapTotalContributions
        let streak = snapshot.heatmapStreakDays

        return HStack(alignment: .top, spacing: TeaPulseSpacing.md) {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                HStack(spacing: TeaPulseSpacing.xs) {
                    Circle()
                        .fill(TeaPulseTheme.primary)
                        .frame(width: 7, height: 7)
                    Text("提交热力")
                        .font(TeaPulseTypography.labelMd)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                        .lineLimit(1)
                }

                Text("\(total)")
                    .font(TeaPulseTypography.headlineLg)
                    .monospacedDigit()
                    .foregroundStyle(TeaPulseTheme.primary)
                    .lineLimit(1)

                Text("近 16 周提交")
                    .font(TeaPulseTypography.labelMd)
                    .foregroundStyle(TeaPulseTheme.secondary)
                    .lineLimit(1)

                HStack(spacing: TeaPulseSpacing.xs) {
                    Image(systemName: "flame.fill")
                        .font(TeaPulseTypography.codeSm)
                        .foregroundStyle(streak > 0 ? TeaPulseTheme.warning : TeaPulseTheme.secondary)
                    Text("连续 \(streak) 天")
                        .font(TeaPulseTypography.codeSm)
                        .monospacedDigit()
                        .foregroundStyle(TeaPulseTheme.onSurface)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, TeaPulseSpacing.xs)
                .padding(.vertical, 2)
                .background(TeaPulseTheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))

                Spacer(minLength: 0)

                HStack(spacing: TeaPulseSpacing.xs) {
                    WidgetRefreshButton()
                    Text(WidgetFormatters.shortTime(snapshot.updatedAt))
                        .font(TeaPulseTypography.codeSm)
                        .monospacedDigit()
                        .foregroundStyle(TeaPulseTheme.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 102, alignment: .leading)

            VStack(alignment: .trailing, spacing: TeaPulseSpacing.xs) {
                heatmapGrid(days: days, weekCount: 16, spacing: 3)
                legendBar
            }
        }
    }

    private var emptyLayout: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
            HStack {
                Circle()
                    .fill(TeaPulseTheme.secondary)
                    .frame(width: 7, height: 7)
                Text("提交热力")
                    .font(TeaPulseTypography.labelMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                Spacer()
                WidgetRefreshButton()
            }
            Spacer()
            Text("打开 TeaPulse 同步实例与贡献热力图")
                .font(TeaPulseTypography.bodySm)
                .foregroundStyle(TeaPulseTheme.secondary)
                .lineLimit(2)
            Spacer()
        }
    }

    private func heatmapGrid(days: [HeatmapDay], weekCount: Int, spacing: CGFloat) -> some View {
        let rows = 7
        let columns: [[HeatmapDay]] = stride(from: 0, to: days.count, by: rows).map { idx in
            Array(days[idx..<min(idx + rows, days.count)])
        }

        return GeometryReader { proxy in
            let availWidth = max(proxy.size.width - spacing * CGFloat(max(weekCount - 1, 1)), 28)
            let availHeight = max(proxy.size.height - spacing * CGFloat(rows - 1), 28)
            let cellSize = max(4, floor(min(availWidth / CGFloat(max(weekCount, 1)), availHeight / CGFloat(rows))))

            HStack(alignment: .top, spacing: spacing) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: spacing) {
                        ForEach(week) { day in
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(WidgetHeatmapPalette.cellColor(for: day.contributions))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private var legendBar: some View {
        HStack(spacing: 3) {
            Text("少")
                .font(TeaPulseTypography.labelMd)
                .foregroundStyle(TeaPulseTheme.secondary)
            ForEach([0, 1, 3, 6], id: \.self) { level in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(WidgetHeatmapPalette.cellColor(for: level))
                    .frame(width: 8, height: 8)
            }
            Text("多")
                .font(TeaPulseTypography.labelMd)
                .foregroundStyle(TeaPulseTheme.secondary)
        }
    }
}

public struct CommitHeatmapWidget: Widget {
    public let kind = "CommitHeatmapWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PulseWidgetProvider()) { entry in
            CommitHeatmapWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("TeaPulse 提交热力")
        .description("桌面绿格子贡献热力图，直观追踪近期提交频次与连续活跃天数，支持一键刷新。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
