import SwiftUI

public enum TeaPulsePlatform {
    public static var showsCodeHorizontalIndicators: Bool {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }
}

public struct TeaPulseModalSheet<Content: View>: View {
    private let title: String
    private let minWidth: CGFloat
    private let idealWidth: CGFloat
    private let minHeight: CGFloat
    private let idealHeight: CGFloat?
    private let onClose: () -> Void
    private let content: () -> Content

    public init(
        title: String,
        minWidth: CGFloat = 480,
        idealWidth: CGFloat = 520,
        minHeight: CGFloat = 340,
        idealHeight: CGFloat? = nil,
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.minWidth = minWidth
        self.idealWidth = idealWidth
        self.minHeight = minHeight
        self.idealHeight = idealHeight
        self.onClose = onClose
        self.content = content
    }

    public var body: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack(spacing: TeaPulseSpacing.sm) {
                Text(title)
                    .font(TeaPulseTypography.headlineMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .lineLimit(1)
                Spacer(minLength: TeaPulseSpacing.sm)
                Button("关闭", action: onClose)
                    .buttonStyle(SecondaryActionButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, TeaPulseSpacing.md)
            .padding(.top, TeaPulseSpacing.md)
            .padding(.bottom, TeaPulseSpacing.sm)

            Rectangle()
                .fill(TeaPulseTheme.cardBorder)
                .frame(height: 1)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: minWidth, idealWidth: idealWidth, minHeight: minHeight, idealHeight: idealHeight)
        .background(TeaPulseTheme.surface)
        #else
        NavigationStack {
            content()
                .background(TeaPulseTheme.surface)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("关闭", action: onClose)
                    }
                }
        }
        #endif
    }
}

public struct TeaPulseBranchTrigger: View {
    private let branch: String
    private let hasBranches: Bool
    private let action: () -> Void
    @State private var isHovered = false

    public init(branch: String, hasBranches: Bool, action: @escaping () -> Void) {
        self.branch = branch
        self.hasBranches = hasBranches
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: TeaPulseSpacing.xs) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(TeaPulseTheme.primary)
                Text(branch)
                    .truncationMode(.middle)
                if hasBranches {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(TeaPulseTheme.secondary)
                }
            }
            .font(TeaPulseTypography.codeSm)
            .foregroundStyle(TeaPulseTheme.onSurface)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, TeaPulseSpacing.md)
            .padding(.vertical, TeaPulseSpacing.xs)
            .frame(minHeight: 34)
            .background(isHovered && hasBranches ? TeaPulseTheme.neutral : TeaPulseTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous)
                    .stroke(TeaPulseTheme.cardBorder, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
        }
        .buttonStyle(TeaPulsePressableCardStyle())
        .onHover { isHovered = $0 }
        .disabled(!hasBranches)
    }
}
