import SwiftUI
import GiteaKit

public struct HeatmapGridView: View {
    public let days: [HeatmapDay]
    public let onlineRunners: Int
    public let totalRunners: Int
    public var isLoading = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false
    @State private var selectedDay: HeatmapDay?

    public init(
        days: [HeatmapDay],
        onlineRunners: Int = 3,
        totalRunners: Int = 4,
        isLoading: Bool = false
    ) {
        self.days = days
        self.onlineRunners = onlineRunners
        self.totalRunners = totalRunners
        self.isLoading = isLoading
    }

    public static func shouldAnimateContinuousWave(reduceMotion: Bool, showLoadingWave: Bool) -> Bool {
        !reduceMotion && showLoadingWave
    }

    private var showLoadingWave: Bool {
        isLoading && days.isEmpty
    }

    private var displayDays: [HeatmapDay] {
        if days.count >= 112 {
            return Array(days.suffix(112))
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let anchor = max(Date(), days.map(\.date).max() ?? Date())
        let endDay = calendar.startOfDay(for: anchor)
        var countsByDay: [Date: Int] = [:]
        for item in days {
            let bucket = calendar.startOfDay(for: item.date)
            countsByDay[bucket, default: 0] += item.contributions
        }
        return (-111...0).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: endDay) ?? endDay
            return HeatmapDay(id: "hm-grid-\(offset)", date: day, contributions: countsByDay[day, default: 0])
        }
    }

    private var weeks: [[HeatmapDay]] {
        let gridDays = displayDays
        return stride(from: 0, to: gridDays.count, by: 7).map { idx in
            Array(gridDays[idx..<min(idx + 7, gridDays.count)])
        }
    }

    private var weeklyTotals: [Int] {
        weeks.map { $0.reduce(0) { $0 + $1.contributions } }
    }

    private var peakWeeklyContributions: Int {
        max(weeklyTotals.max() ?? 0, 1)
    }

    private var totalContributions: Int {
        displayDays.reduce(0) { $0 + $1.contributions }
    }

    private var streakDays: Int {
        var streak = 0
        for day in displayDays.reversed() {
            if day.contributions > 0 {
                streak += 1
            } else if streak > 0 {
                break
            }
        }
        return streak
    }

    public var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                headerRow
                heatmapMatrix
                footerCaption
            }
        }
        .task(id: showLoadingWave) {
            if showLoadingWave {
                isRevealed = false
                selectedDay = nil
                return
            }
            if reduceMotion {
                isRevealed = true
                return
            }
            isRevealed = false
            try? await Task.sleep(for: .milliseconds(16))
            guard !Task.isCancelled else { return }
            withAnimation(TeaPulseMotion.spring) {
                isRevealed = true
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: TeaPulseSpacing.sm) {
            Text("16 周提交热力")
                .font(TeaPulseTypography.headlineMd)
                .foregroundStyle(TeaPulseTheme.onSurface)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Spacer()
            if showLoadingWave {
                HStack(spacing: TeaPulseSpacing.xs) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(TeaPulseTheme.primary)
                    Text("正在同步热力…")
                        .font(TeaPulseTypography.codeSm)
                        .foregroundStyle(TeaPulseTheme.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("\(totalContributions) 次提交 · 连续 \(streakDays) 天")
                    .font(TeaPulseTypography.codeSm)
                    .monospacedDigit()
                    .foregroundStyle(TeaPulseTheme.primary)
                    .lineLimit(1)
                    .teaPulseNumericTransition(value: totalContributions)
            }
        }
    }

    private var heatmapMatrix: some View {
        let animateTimeline = Self.shouldAnimateContinuousWave(reduceMotion: reduceMotion, showLoadingWave: showLoadingWave)
        let columns = weeks
        let totals = weeklyTotals
        let peak = peakWeeklyContributions

        return TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animateTimeline)) { context in
            let phase = animateTimeline ? context.date.timeIntervalSinceReferenceDate : 0
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: TeaPulseSpacing.xs) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { colIndex, week in
                        let colVisible = reduceMotion || (!showLoadingWave && isRevealed)
                        let weekTotal = colIndex < totals.count ? totals[colIndex] : 0
                        let hasSelectedDay = selectedDay.map { sel in week.contains { $0.id == sel.id } } ?? false

                        VStack(spacing: TeaPulseSpacing.xs) {
                            ForEach(Array(week.enumerated()), id: \.element.id) { rowIndex, day in
                                dayCell(day: day, colIndex: colIndex, rowIndex: rowIndex, phase: phase, colVisible: colVisible)
                            }
                            trendBar(colIndex: colIndex, weekTotal: weekTotal, peak: peak, phase: phase, colVisible: colVisible, highlighted: hasSelectedDay)
                                .padding(.top, TeaPulseSpacing.xs)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func dayCell(day: HeatmapDay, colIndex: Int, rowIndex: Int, phase: TimeInterval, colVisible: Bool) -> some View {
        if showLoadingWave {
            let wave = reduceMotion ? 0.5 : 0.5 + 0.5 * sin(phase * 4.2 - Double(colIndex) * 0.35 - Double(rowIndex) * 0.18)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(TeaPulseTheme.neutral)
                .overlay(
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(TeaPulseTheme.primary.opacity(0.14 + wave * 0.42))
                )
                .frame(width: 12, height: 12)
                .scaleEffect(reduceMotion ? 1.0 : 0.86 + wave * 0.14)
        } else {
            let isSelected = selectedDay?.id == day.id
            Button {
                TeaPulseMotion.run(TeaPulseMotion.snappy, reduceMotion: reduceMotion) {
                    selectedDay = isSelected ? nil : day
                }
            } label: {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(cellColor(for: day.contributions))
                    .frame(width: 12, height: 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .stroke(TeaPulseTheme.onSurface, lineWidth: isSelected ? 1.5 : 0)
                    )
                    .scaleEffect(isSelected ? 1.22 : (colVisible ? 1.0 : 0.6))
                    .opacity(colVisible ? 1.0 : 0.0)
                    .animation(
                        reduceMotion ? nil : TeaPulseMotion.spring.delay(Double(colIndex) * 0.018),
                        value: colVisible
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(Self.dayFormatter.string(from: day.date)) \(day.contributions) 次提交")
        }
    }

    @ViewBuilder
    private func trendBar(
        colIndex: Int,
        weekTotal: Int,
        peak: Int,
        phase: TimeInterval,
        colVisible: Bool,
        highlighted: Bool
    ) -> some View {
        let targetHeight: CGFloat = {
            if showLoadingWave {
                let wave = reduceMotion ? 0.5 : 0.5 + 0.5 * sin(phase * 4.2 - Double(colIndex) * 0.35)
                return 6 + wave * 14
            }
            guard colVisible else { return 4 }
            if weekTotal == 0 { return 4 }
            return 6 + 16 * CGFloat(weekTotal) / CGFloat(peak)
        }()
        let barColor: Color = {
            if showLoadingWave { return TeaPulseTheme.primary.opacity(0.42) }
            if highlighted { return TeaPulseTheme.primary }
            return weekTotal > 0 ? TeaPulseTheme.primary.opacity(0.65) : TeaPulseTheme.neutral.opacity(0.55)
        }()

        ZStack(alignment: .bottom) {
            Capsule(style: .continuous)
                .fill(barColor)
                .frame(width: 8, height: targetHeight)
                .animation(
                    reduceMotion || showLoadingWave ? nil : TeaPulseMotion.spring.delay(Double(colIndex) * 0.022),
                    value: colVisible
                )
        }
        .frame(width: 12, height: 22, alignment: .bottom)
    }

    private var footerCaption: some View {
        Group {
            if let selectedDay {
                Text("选中 \(Self.dayFormatter.string(from: selectedDay.date)) · \(selectedDay.contributions) 次提交 · 再次点击取消")
                    .foregroundStyle(TeaPulseTheme.primary)
            } else {
                Text(totalContributions > 0 ? "近 16 周共 \(totalContributions) 次提交 · 在线执行节点 \(onlineRunners)/\(totalRunners)" : "近 16 周暂无提交记录 · 在线执行节点 \(onlineRunners)/\(totalRunners)")
                    .foregroundStyle(TeaPulseTheme.secondary)
            }
        }
        .font(TeaPulseTypography.labelMd)
        .monospacedDigit()
        .animation(reduceMotion ? nil : TeaPulseMotion.subtle, value: selectedDay?.id)
    }

    private func cellColor(for count: Int) -> Color {
        switch count {
        case 0: return TeaPulseTheme.surfaceElevated
        case 1...2: return TeaPulseTheme.primary.opacity(0.30)
        case 3...5: return TeaPulseTheme.primary.opacity(0.60)
        default: return TeaPulseTheme.primary
        }
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "MM-dd"
        return formatter
    }()
}
