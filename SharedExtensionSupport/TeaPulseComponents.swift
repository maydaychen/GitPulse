import SwiftUI
import GiteaKit

public struct SurfaceCard<Content: View>: View {
    private let padding: CGFloat
    private let elevated: Bool
    private let isSelected: Bool
    private let content: () -> Content

    public init(
        padding: CGFloat = TeaPulseSpacing.md,
        elevated: Bool = false,
        isSelected: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.elevated = elevated
        self.isSelected = isSelected
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding)
            .background((elevated || isSelected) ? TeaPulseTheme.surfaceElevated : TeaPulseTheme.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TeaPulseRadius.lg, style: .continuous)
                    .stroke(isSelected ? TeaPulseTheme.primary : TeaPulseTheme.cardBorder, lineWidth: isSelected ? 1.5 : 1)
            )
    }
}

public struct StatusBadge: View {
    public enum Tone: Sendable {
        case primary
        case tertiary
        case warning
        case error
        case neutral

        var foreground: Color {
            switch self {
            case .primary: return TeaPulseTheme.primary
            case .tertiary: return TeaPulseTheme.tertiary
            case .warning: return TeaPulseTheme.warning
            case .error: return TeaPulseTheme.error
            case .neutral: return TeaPulseTheme.secondary
            }
        }
    }

    private let text: String
    private let tone: Tone

    public init(_ text: String, tone: Tone) {
        self.text = text
        self.tone = tone
    }

    public var body: some View {
        Text(text)
            .font(TeaPulseTypography.codeSm)
            .monospacedDigit()
            .foregroundStyle(tone.foreground)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, TeaPulseSpacing.sm)
            .padding(.vertical, TeaPulseSpacing.xs)
            .background(TeaPulseTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous)
                    .stroke(tone.foreground.opacity(0.28), lineWidth: 1)
            )
    }
}

public struct BranchRoutePill: View {
    private let routeText: String

    public init(_ routeText: String) {
        self.routeText = routeText
    }

    public var body: some View {
        Text(routeText)
            .font(TeaPulseTypography.codeSm)
            .foregroundStyle(TeaPulseTheme.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, TeaPulseSpacing.sm)
            .padding(.vertical, TeaPulseSpacing.xs)
            .background(TeaPulseTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous)
                    .stroke(TeaPulseTheme.cardBorder, lineWidth: 1)
            )
    }
}

public struct PulsingStatusDot: View {
    private let color: Color
    private let animate: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false

    public init(color: Color, animate: Bool = true) {
        self.color = color
        self.animate = animate
    }

    public var body: some View {
        ZStack {
            if animate && !reduceMotion {
                Circle()
                    .stroke(color.opacity(isExpanded ? 0.0 : 0.55), lineWidth: 1.5)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isExpanded ? 2.1 : 1.0)
            }
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .scaleEffect(animate && !reduceMotion && isExpanded ? 1.12 : 1.0)
        }
        .frame(width: 14, height: 14)
        .onAppear {
            startPulseIfNeeded()
        }
        .onChange(of: animate) { _, newValue in
            if newValue && !reduceMotion {
                isExpanded = false
                startPulseIfNeeded()
            } else {
                isExpanded = false
            }
        }
        .onChange(of: reduceMotion) { _, _ in
            isExpanded = false
            startPulseIfNeeded()
        }
    }

    private func startPulseIfNeeded() {
        guard animate && !reduceMotion else {
            isExpanded = false
            return
        }
        withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
            isExpanded = true
        }
    }
}

public struct PrimaryActionButtonStyle: ButtonStyle {
    private let fullWidth: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(fullWidth: Bool = false) {
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TeaPulseTypography.labelMd)
            .foregroundStyle(TeaPulseTheme.onPrimary)
            .lineLimit(1)
            .fixedSize(horizontal: !fullWidth, vertical: false)
            .padding(.horizontal, TeaPulseSpacing.md)
            .padding(.vertical, TeaPulseSpacing.sm)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
            .background(configuration.isPressed ? TeaPulseTheme.primaryHover : TeaPulseTheme.primaryAction)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : TeaPulseMotion.snappy, value: configuration.isPressed)
    }
}

public struct SecondaryActionButtonStyle: ButtonStyle {
    private let fullWidth: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(fullWidth: Bool = false) {
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(TeaPulseTypography.bodySm)
            .foregroundStyle(TeaPulseTheme.onSurface)
            .lineLimit(1)
            .fixedSize(horizontal: !fullWidth, vertical: false)
            .padding(.horizontal, TeaPulseSpacing.md)
            .padding(.vertical, TeaPulseSpacing.xs)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 36)
            .background(TeaPulseTheme.neutral.opacity(configuration.isPressed ? 0.7 : 1.0))
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous)
                    .stroke(TeaPulseTheme.cardBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .animation(reduceMotion ? nil : TeaPulseMotion.snappy, value: configuration.isPressed)
    }
}

public struct FilterChipButton: View {
    private let title: String
    private let count: Int?
    private let isSelected: Bool
    private let action: () -> Void

    public init(
        title: String,
        count: Int? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.count = count
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: TeaPulseSpacing.xs) {
                Text(title)
                    .font(TeaPulseTypography.labelMd)
                if let count {
                    Text("\(count)")
                        .font(TeaPulseTypography.codeSm)
                        .monospacedDigit()
                        .opacity(0.85)
                }
            }
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, TeaPulseSpacing.md)
            .padding(.vertical, TeaPulseSpacing.sm)
            .frame(minHeight: 36)
            .foregroundStyle(isSelected ? TeaPulseTheme.onPrimary : TeaPulseTheme.onSurface)
            .background(isSelected ? TeaPulseTheme.primaryAction : TeaPulseTheme.surfaceElevated)
            .clipShape(Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(isSelected ? TeaPulseTheme.primaryAction : TeaPulseTheme.cardBorder, lineWidth: 1)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(TeaPulsePressableCardStyle())
    }
}

public extension RunStatus {
    var badgeTone: StatusBadge.Tone {
        switch self {
        case .running: return .warning
        case .waitingApproval: return .tertiary
        case .success: return .primary
        case .failure: return .error
        }
    }
}

public struct LoadingSkeletonRows: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let rowTrailingInsets: [CGFloat] = [0, 56, 128]

    public init() {}

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let phase = reduceMotion ? 0.0 : context.date.timeIntervalSinceReferenceDate
            let cycle = phase.truncatingRemainder(dividingBy: 1.35) / 1.35
            let center = -0.35 + cycle * 1.7

            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                ForEach(Array(rowTrailingInsets.enumerated()), id: \.offset) { index, trailing in
                    let wave = reduceMotion ? 0.8 : 0.62 + 0.38 * (0.5 + 0.5 * sin(phase * 3.4 - Double(index) * 0.75))
                    RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous)
                        .fill(TeaPulseTheme.neutral)
                        .overlay {
                            if !reduceMotion {
                                LinearGradient(
                                    colors: [
                                        TeaPulseTheme.neutral.opacity(0),
                                        TeaPulseTheme.primary.opacity(0.24),
                                        TeaPulseTheme.onSurface.opacity(0.12),
                                        TeaPulseTheme.neutral.opacity(0),
                                    ],
                                    startPoint: UnitPoint(x: center - 0.35, y: 0.5),
                                    endPoint: UnitPoint(x: center + 0.35, y: 0.5)
                                )
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
                        .frame(height: 12)
                        .padding(.trailing, trailing)
                        .opacity(wave)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

public struct LoadingStateCard: View {
    private let title: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ title: String = "正在加载数据…") {
        self.title = title
    }

    public var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
                    let phase = reduceMotion ? 0.0 : context.date.timeIntervalSinceReferenceDate
                    HStack(spacing: TeaPulseSpacing.sm) {
                        ProgressView()
                            .tint(TeaPulseTheme.primary)
                        Text(title)
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                        Spacer()
                        HStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { bar in
                                let pulse = reduceMotion ? 0.6 : 0.5 + 0.5 * sin(phase * 4.8 + Double(bar) * 0.9)
                                Capsule(style: .continuous)
                                    .fill(TeaPulseTheme.primary)
                                    .frame(width: 3, height: 6 + pulse * 10)
                                    .opacity(0.45 + pulse * 0.55)
                            }
                        }
                        .frame(height: 16)
                    }
                }
                LoadingSkeletonRows()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
    }
}

public struct TeaPulseDropdownItem<Value: Hashable & Sendable>: Identifiable, Sendable {
    public var id: Value { value }
    public let value: Value
    public let title: String
    public let icon: String
    public let accessibilityID: String?

    public init(value: Value, title: String, icon: String, accessibilityID: String? = nil) {
        self.value = value
        self.title = title
        self.icon = icon
        self.accessibilityID = accessibilityID
    }
}

/// Cross-platform themed dropdown selector using a custom borderless popover on macOS and native Menu on iOS.
public struct TeaPulseDropdownMenu<Value: Hashable & Sendable>: View {
    private let items: [TeaPulseDropdownItem<Value>]
    @Binding private var selection: Value
    private let triggerAccessibilityID: String?
    private let preferredColorScheme: ColorScheme?
    @State private var isExpanded = false
    @State private var isTriggerHovered = false
    @State private var hoveredValue: Value?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        items: [TeaPulseDropdownItem<Value>],
        selection: Binding<Value>,
        triggerAccessibilityID: String? = nil,
        preferredColorScheme: ColorScheme? = nil
    ) {
        self.items = items
        self._selection = selection
        self.triggerAccessibilityID = triggerAccessibilityID
        self.preferredColorScheme = preferredColorScheme
    }

    private var currentItem: TeaPulseDropdownItem<Value>? { items.first { $0.value == selection } ?? items.first }

    public var body: some View {
        #if os(macOS)
        Button {
            TeaPulseMotion.run(TeaPulseMotion.snappy, reduceMotion: reduceMotion) { isExpanded.toggle() }
        } label: {
            triggerLabel
        }
        .buttonStyle(TeaPulsePressableCardStyle())
        .onHover { isTriggerHovered = $0 }
        .ifLet(triggerAccessibilityID) { $0.accessibilityIdentifier($1) }
        .popover(isPresented: $isExpanded, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) { popoverContent }
        #else
        Menu {
            ForEach(items) { item in
                Button { selection = item.value } label: {
                    Label(item.title, systemImage: selection == item.value ? "checkmark" : item.icon)
                }
                .ifLet(item.accessibilityID) { $0.accessibilityIdentifier($1) }
            }
        } label: {
            triggerLabel
        }
        .ifLet(triggerAccessibilityID) { $0.accessibilityIdentifier($1) }
        #endif
    }

    private var triggerLabel: some View {
        HStack(spacing: TeaPulseSpacing.sm) {
            if let current = currentItem {
                Image(systemName: current.icon).foregroundStyle(TeaPulseTheme.primary)
                Text(current.title)
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(TeaPulseTheme.secondary)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .font(TeaPulseTypography.codeSm)
        .foregroundStyle(TeaPulseTheme.onSurface)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, TeaPulseSpacing.md)
        .padding(.vertical, TeaPulseSpacing.sm)
        .frame(minHeight: 36)
        .background(isTriggerHovered || isExpanded ? TeaPulseTheme.neutral : TeaPulseTheme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous)
                .stroke(isExpanded ? TeaPulseTheme.primary.opacity(0.75) : TeaPulseTheme.cardBorder, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
    }

    #if os(macOS)
    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
            ForEach(items) { item in
                let isSelected = selection == item.value
                let isHovered = hoveredValue == item.value
                Button {
                    selection = item.value
                    isExpanded = false
                } label: {
                    HStack(spacing: TeaPulseSpacing.sm) {
                        Image(systemName: item.icon)
                            .frame(width: 16)
                            .foregroundStyle(isSelected ? TeaPulseTheme.primary : TeaPulseTheme.secondary)
                        Text(item.title)
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                            .lineLimit(1)
                        Spacer(minLength: TeaPulseSpacing.md)
                        if isSelected {
                            Image(systemName: "checkmark").font(TeaPulseTypography.codeSm).foregroundStyle(TeaPulseTheme.primary)
                        }
                    }
                    .padding(.horizontal, TeaPulseSpacing.sm)
                    .padding(.vertical, TeaPulseSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isSelected ? TeaPulseTheme.primary.opacity(0.14) : (isHovered ? TeaPulseTheme.neutral : Color.clear))
                    .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
                }
                .buttonStyle(.plain)
                .onHover { hoveredValue = $0 ? item.value : (hoveredValue == item.value ? nil : hoveredValue) }
                .ifLet(item.accessibilityID) { $0.accessibilityIdentifier($1) }
            }
        }
        .padding(TeaPulseSpacing.sm)
        .frame(minWidth: 148)
        .background(TeaPulseTheme.surfaceElevated)
        .presentationBackground(TeaPulseTheme.surfaceElevated)
        .preferredColorScheme(preferredColorScheme)
    }
    #endif
}

private extension View {
    @ViewBuilder
    func ifLet<T, Transformed: View>(_ value: T?, transform: (Self, T) -> Transformed) -> some View {
        if let value { transform(self, value) } else { self }
    }
}
