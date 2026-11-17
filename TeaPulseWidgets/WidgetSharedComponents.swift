import AppIntents
import Foundation
import GiteaKit
import SwiftUI

struct WidgetRefreshButton: View {
    var body: some View {
        Button(intent: RefreshPulseWidgetsIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(TeaPulseTypography.codeSm)
                .foregroundStyle(TeaPulseTheme.secondary)
                .frame(width: 22, height: 22)
                .background(TeaPulseTheme.surfaceElevated)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(TeaPulseTheme.cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("刷新小组件")
    }
}

struct WidgetMetricBlock: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(TeaPulseTypography.headlineMd)
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
            Text(label)
                .font(TeaPulseTypography.labelMd)
                .foregroundStyle(TeaPulseTheme.secondary)
                .lineLimit(1)
        }
    }
}

enum WidgetHeatmapPalette {
    static func cellColor(for count: Int) -> Color {
        switch count {
        case 0:
            return TeaPulseTheme.surfaceElevated
        case 1...2:
            return TeaPulseTheme.primary.opacity(0.32)
        case 3...5:
            return TeaPulseTheme.primary.opacity(0.62)
        default:
            return TeaPulseTheme.primary
        }
    }
}

struct WidgetTriageIcon: View {
    let kind: TriageKind

    var body: some View {
        Image(systemName: symbolName)
            .font(TeaPulseTypography.codeSm)
            .foregroundStyle(accentColor)
            .frame(width: 18, height: 18)
            .background(TeaPulseTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
    }

    private var symbolName: String {
        switch kind {
        case .pullRequest:
            return "arrow.triangle.pull"
        case .failedRun:
            return "xmark.octagon.fill"
        case .offlineRunner:
            return "bolt.horizontal.circle.fill"
        }
    }

    private var accentColor: Color {
        switch kind {
        case .pullRequest:
            return TeaPulseTheme.primary
        case .failedRun:
            return TeaPulseTheme.error
        case .offlineRunner:
            return TeaPulseTheme.warning
        }
    }
}

enum WidgetFormatters {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    static func shortTime(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    static func statusColor(for snapshot: WidgetDashboardSnapshot?) -> Color {
        guard let snapshot else { return TeaPulseTheme.secondary }
        if snapshot.failedBuildCount > 0 || snapshot.offlineRunnerCount > 0 {
            return TeaPulseTheme.error
        }
        if snapshot.runningBuildCount > 0 {
            return TeaPulseTheme.warning
        }
        return TeaPulseTheme.primary
    }
}
