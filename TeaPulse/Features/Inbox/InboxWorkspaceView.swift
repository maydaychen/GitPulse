import SwiftUI
import GiteaKit

public struct InboxWorkspaceView: View {
    @Environment(AppStore.self) private var store
    @State private var showBarkConfig = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.lg) {
                headerRow
                categoryBar
                threadList
            }
            .padding(TeaPulseSpacing.md)
        }
        .background(TeaPulseTheme.surface)
        .refreshable {
            await store.refreshLiveInstanceData()
        }
        .sheet(isPresented: $showBarkConfig) {
            BarkPushConfigSheet()
                .preferredColorScheme(store.themePreference.colorScheme)
        }
    }

    private var headerRow: some View {
        HStack(spacing: TeaPulseSpacing.sm) {
            Text("通知")
                .font(TeaPulseTypography.headlineLg)
                .foregroundStyle(TeaPulseTheme.onSurface)
                .lineLimit(1)
            if store.unreadInboxCount > 0 {
                StatusBadge("\(store.unreadInboxCount) 未读", tone: .primary)
            }
            Spacer()
            Button("全部已读") {
                Task { await store.markAllThreadsRead() }
            }
            .buttonStyle(SecondaryActionButtonStyle())
            Button("推送设置") {
                showBarkConfig = true
            }
            .buttonStyle(SecondaryActionButtonStyle())
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TeaPulseSpacing.sm) {
                FilterChipButton(title: "全部", isSelected: store.showAllInbox) {
                    store.showAllInbox = true
                }
                ForEach(NotificationCategory.allCases, id: \.self) { category in
                    FilterChipButton(
                        title: category.rawValue,
                        isSelected: !store.showAllInbox && store.inboxCategory == category
                    ) {
                        store.showAllInbox = false
                        store.inboxCategory = category
                    }
                }
            }
        }
    }

    private var threadList: some View {
        VStack(spacing: TeaPulseSpacing.md) {
            if store.filteredNotifications.isEmpty {
                if store.isInitialWorkspaceLoading {
                    LoadingStateCard("正在加载通知…")
                } else {
                    SurfaceCard {
                        Text("当前分类下暂无通知")
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            ForEach(store.filteredNotifications) { thread in
                SurfaceCard {
                    VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                        Button {
                            openThread(thread)
                        } label: {
                            VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                                HStack(spacing: TeaPulseSpacing.sm) {
                                    if thread.unread {
                                        PulsingStatusDot(color: TeaPulseTheme.primary, animate: false)
                                    }
                                    StatusBadge(thread.category.rawValue, tone: thread.category == .ciAlert ? .error : .neutral)
                                    Spacer()
                                    Text(thread.updatedAtText)
                                        .font(TeaPulseTypography.codeSm)
                                        .monospacedDigit()
                                        .foregroundStyle(TeaPulseTheme.secondary)
                                }

                                Text(thread.repoFullName)
                                    .font(TeaPulseTypography.codeSm)
                                    .foregroundStyle(TeaPulseTheme.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Text(thread.subjectTitle)
                                    .font(TeaPulseTypography.bodyMd)
                                    .foregroundStyle(TeaPulseTheme.onSurface)
                                    .lineLimit(3)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(TeaPulsePressableCardStyle())

                        if thread.unread {
                            HStack {
                                Spacer()
                                Button("已读") {
                                    Task { await store.markThreadRead(thread.id) }
                                }
                                .buttonStyle(SecondaryActionButtonStyle())
                            }
                        }
                    }
                }
                .contextMenu {
                    if thread.unread {
                        Button("标为已读") {
                            Task { await store.markThreadRead(thread.id) }
                        }
                    }
                    Button(thread.isMutedRepo ? "取消静音" : "静音仓库") {
                        store.toggleMuteRepo(thread.repoFullName)
                    }
                }
            }
        }
    }

    private func openThread(_ thread: NotificationThread) {
        store.handle(deepLinkString: thread.deepLink)
    }
}
