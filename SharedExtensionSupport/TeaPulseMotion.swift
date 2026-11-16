import SwiftUI

public enum TeaPulseMotion {
    public static let snappy = Animation.snappy(duration: 0.24, extraBounce: 0.06)
    public static let spring = Animation.spring(duration: 0.32, bounce: 0.14)
    public static let subtle = Animation.easeOut(duration: 0.20)

    public static func run(
        _ animation: Animation = snappy,
        reduceMotion: Bool,
        _ body: () -> Void
    ) {
        if reduceMotion {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction, body)
        } else {
            withAnimation(animation, body)
        }
    }
}

public struct TeaPulsePressableCardStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(reduceMotion ? nil : TeaPulseMotion.snappy, value: configuration.isPressed)
    }
}

private struct StaggeredRevealModifier: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion || isVisible ? 1.0 : 0.0)
            .offset(y: reduceMotion || isVisible ? 0 : 8)
            .onAppear {
                guard !isVisible else { return }
                if reduceMotion {
                    isVisible = true
                } else {
                    let delay = Double(min(max(index, 0), 8)) * 0.035
                    withAnimation(TeaPulseMotion.spring.delay(delay)) {
                        isVisible = true
                    }
                }
            }
    }
}

private struct NumericTransitionModifier<Value: Equatable>: ViewModifier {
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .contentTransition(.numericText())
                .animation(TeaPulseMotion.snappy, value: value)
        }
    }
}

public extension View {
    func teaPulseStaggeredReveal(index: Int = 0) -> some View {
        modifier(StaggeredRevealModifier(index: index))
    }

    func teaPulseNumericTransition<Value: Equatable>(value: Value) -> some View {
        modifier(NumericTransitionModifier(value: value))
    }
}
