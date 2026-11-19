import SwiftUI
import GiteaKit

public struct CommandPaletteView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var isFocused: Bool

    public init() {}

    private var matches: [CommandPaletteEntry] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return store.commandPaletteEntries }
        return store.commandPaletteEntries.filter {
            $0.title.lowercased().contains(q)
                || $0.subtitle.lowercased().contains(q)
                || $0.badge.lowercased().contains(q)
        }
    }

    public var body: some View {
        VStack(spacing: TeaPulseSpacing.md) {
            HStack(spacing: TeaPulseSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(TeaPulseTheme.secondary)
                TextField("搜索仓库、合并请求、工作流或执行节点…", text: $query)
                    .textFieldStyle(.plain)
                    .font(TeaPulseTypography.bodyMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .focused($isFocused)
                    .onSubmit {
                        if let first = matches.first {
                            select(first)
                        }
                    }
                Button {
                    dismiss()
                } label: {
                    Text("关闭")
                        .font(TeaPulseTypography.codeSm)
                        .foregroundStyle(TeaPulseTheme.secondary)
                        .padding(.horizontal, TeaPulseSpacing.sm)
                        .padding(.vertical, TeaPulseSpacing.xs)
                        .frame(minHeight: 32)
                        .background(TeaPulseTheme.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
                        .contentShape(Rectangle())
                }
                .buttonStyle(TeaPulsePressableCardStyle())
                .keyboardShortcut(.cancelAction)
            }
            .padding(TeaPulseSpacing.md)
            .background(TeaPulseTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))

            ScrollView {
                LazyVStack(spacing: TeaPulseSpacing.sm) {
                    if matches.isEmpty {
                        SurfaceCard {
                            Text("未找到匹配项目")
                                .font(TeaPulseTypography.bodySm)
                                .foregroundStyle(TeaPulseTheme.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    ForEach(matches) { item in
                        Button {
                            select(item)
                        } label: {
                            HStack(spacing: TeaPulseSpacing.sm) {
                                VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                                    Text(item.title)
                                        .font(TeaPulseTypography.bodyMd)
                                        .foregroundStyle(TeaPulseTheme.onSurface)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Text(item.subtitle)
                                        .font(TeaPulseTypography.codeSm)
                                        .foregroundStyle(TeaPulseTheme.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                StatusBadge(item.badge, tone: .neutral)
                            }
                            .padding(TeaPulseSpacing.sm)
                            .background(TeaPulseTheme.surfaceCard)
                            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(TeaPulsePressableCardStyle())
                    }
                }
            }
            .frame(maxHeight: 360)
        }
        .padding(TeaPulseSpacing.lg)
        #if os(macOS)
        .frame(minWidth: 560, idealWidth: 600, minHeight: 420, idealHeight: 460)
        #endif
        .background(TeaPulseTheme.surface)
        .onAppear { isFocused = true }
    }

    private func select(_ entry: CommandPaletteEntry) {
        store.handle(deepLinkString: entry.deepLink)
        dismiss()
    }
}
