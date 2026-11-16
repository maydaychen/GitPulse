#if canImport(ActivityKit) && os(iOS)
import ActivityKit
import WidgetKit
import SwiftUI

public struct BuildLiveActivityWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: BuildActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                HStack {
                    Text("\(context.attributes.repoFullName) #\(context.attributes.runNumber)")
                        .font(TeaPulseTypography.codeSm)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                    Spacer()
                    Text("\(context.state.elapsedSeconds)s")
                        .font(TeaPulseTypography.codeSm)
                        .monospacedDigit()
                        .foregroundStyle(TeaPulseTheme.primary)
                }
                Text(context.state.currentStepName)
                    .font(TeaPulseTypography.bodySm)
                    .foregroundStyle(TeaPulseTheme.secondary)
                    .lineLimit(1)
                ProgressView(
                    value: Double(context.state.completedSteps),
                    total: Double(max(context.state.totalSteps, 1))
                )
                .tint(TeaPulseTheme.primary)
            }
            .padding(TeaPulseSpacing.md)
            .activityBackgroundTint(TeaPulseTheme.surfaceCard)
            .activitySystemActionForegroundColor(TeaPulseTheme.onSurface)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("#\(context.attributes.runNumber)")
                        .font(TeaPulseTypography.codeSm)
                        .foregroundStyle(TeaPulseTheme.primary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.elapsedSeconds)s")
                        .font(TeaPulseTypography.codeSm)
                        .monospacedDigit()
                        .foregroundStyle(TeaPulseTheme.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.currentStepName)
                        .font(TeaPulseTypography.labelMd)
                        .lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(TeaPulseTheme.primary)
            } compactTrailing: {
                Text("\(context.state.completedSteps)/\(context.state.totalSteps)")
                    .font(TeaPulseTypography.codeSm)
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "play.fill")
                    .foregroundStyle(TeaPulseTheme.primary)
            }
        }
    }
}
#endif
