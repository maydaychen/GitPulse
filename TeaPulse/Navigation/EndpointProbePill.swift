import SwiftUI
import GiteaKit

public struct EndpointProbePill: View {
    public let health: EndpointHealth
    public let action: () -> Void

    public init(health: EndpointHealth, action: @escaping () -> Void) {
        self.health = health
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
        Button(action: action) {
            HStack(spacing: TeaPulseSpacing.sm) {
                PulsingStatusDot(color: dotColor, animate: health.serverVersion != "unreachable")
                Text(health.probePillText)
                    .font(TeaPulseTypography.codeSm)
                    .monospacedDigit()
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, TeaPulseSpacing.md)
            .padding(.vertical, TeaPulseSpacing.sm)
            .frame(minHeight: 36)
            .background(TeaPulseTheme.surfaceElevated)
            .clipShape(Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(TeaPulsePressableCardStyle())
        .accessibilityIdentifier("endpointProbePill")
    }
}
