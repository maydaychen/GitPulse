import SwiftUI
import GiteaKit

public struct EndpointProbePill: View {
    public let health: EndpointHealth
    private let fullWidth: Bool
    public let action: () -> Void

    public init(health: EndpointHealth, fullWidth: Bool = false, action: @escaping () -> Void) {
        self.health = health
        self.fullWidth = fullWidth
        self.action = action
    }

    private var dotColor: Color {
        if health.serverVersion == "unreachable" {
            return TeaPulseTheme.error
        }
        switch health.channel {
        case .lanDirect: return TeaPulseTheme.primary
        case .publicProxy: return TeaPulseTheme.primary
        case .demo: return TeaPulseTheme.tertiary
        }
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: fullWidth ? TeaPulseRadius.md : 18, style: .continuous)
        Button(action: action) {
            HStack(spacing: TeaPulseSpacing.sm) {
                PulsingStatusDot(color: dotColor, animate: health.serverVersion != "unreachable")
                Text(health.probePillText)
                    .font(TeaPulseTypography.codeSm)
                    .monospacedDigit()
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: !fullWidth, vertical: false)
                if fullWidth {
                    Spacer(minLength: TeaPulseSpacing.xs)
                    Image(systemName: "slider.horizontal.3")
                        .font(TeaPulseTypography.codeSm)
                        .foregroundStyle(TeaPulseTheme.secondary)
                }
            }
            .padding(.horizontal, TeaPulseSpacing.md)
            .padding(.vertical, TeaPulseSpacing.sm)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 36, alignment: .leading)
            .background(TeaPulseTheme.surfaceElevated)
            .clipShape(shape)
            .overlay(shape.stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(TeaPulsePressableCardStyle())
        .accessibilityIdentifier("endpointProbePill")
    }
}

/// Custom segmented theme switcher aligned with TeaPulse surface and border tokens.
public struct TeaPulseThemeSwitcher: View {
    @Binding private var selection: ThemePreference
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var thumbNamespace
    @State private var hoveredOption: ThemePreference?

    public init(selection: Binding<ThemePreference>) {
        self._selection = selection
    }

    private var activeThumbFill: Color {
        colorScheme == .dark ? TeaPulseTheme.neutral : TeaPulseTheme.surfaceCard
    }

    public var body: some View {
        HStack(spacing: TeaPulseSpacing.xs) {
            ForEach(ThemePreference.allCases) { option in
                let isSelected = selection == option
                let isHovered = hoveredOption == option
                Button {
                    TeaPulseMotion.run(TeaPulseMotion.snappy, reduceMotion: reduceMotion) {
                        selection = option
                    }
                } label: {
                    HStack(spacing: TeaPulseSpacing.xs) {
                        Image(systemName: option.iconName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isSelected ? TeaPulseTheme.primary : (isHovered ? TeaPulseTheme.onSurface : TeaPulseTheme.secondary))
                        Text(option.rawValue)
                            .font(TeaPulseTypography.labelMd)
                            .fontWeight(isSelected ? .semibold : .medium)
                            .foregroundStyle(isSelected ? TeaPulseTheme.onSurface : TeaPulseTheme.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous)
                                .fill(activeThumbFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous)
                                        .stroke(TeaPulseTheme.primary.opacity(0.45), lineWidth: 1)
                                )
                                .matchedGeometryEffect(id: "themeThumb", in: thumbNamespace)
                        } else if isHovered {
                            RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous)
                                .fill(TeaPulseTheme.neutral.opacity(0.55))
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    hoveredOption = hovering ? option : (hoveredOption == option ? nil : hoveredOption)
                }
                .accessibilityIdentifier("themeSegment-\(option.rawValue)")
            }
        }
        .padding(TeaPulseSpacing.xs)
        .background(TeaPulseTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous)
                .stroke(TeaPulseTheme.cardBorder, lineWidth: 1)
        )
    }
}
