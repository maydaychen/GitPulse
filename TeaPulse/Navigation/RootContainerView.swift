import SwiftUI
import GiteaKit

public struct RootContainerView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    public init() {}

    private var useCompactShell: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }

    public var body: some View {
        @Bindable var bindableStore = store

        ZStack(alignment: .bottom) {
            Group {
                if useCompactShell {
                    compactTabShell
                } else {
                    splitWorkspaceShell
                }
            }

            if let banner = store.simulatedPushBanner {
                VStack {
                    Button {
                        store.handle(deepLinkString: banner.deepLink)
                        store.simulatedPushBanner = nil
                    } label: {
                        HStack(spacing: TeaPulseSpacing.sm) {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(TeaPulseTheme.error)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(banner.repoFullName)
                                    .font(TeaPulseTypography.codeSm)
                                    .foregroundStyle(TeaPulseTheme.secondary)
                                    .lineLimit(1)
                                Text(banner.subjectTitle)
                                    .font(TeaPulseTypography.bodySm)
                                    .foregroundStyle(TeaPulseTheme.onSurface)
                                    .lineLimit(1)
                            }
                            Spacer()
                            StatusBadge("直达报错行", tone: .error)
                        }
                        .padding(TeaPulseSpacing.sm)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.lg, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: TeaPulseRadius.lg, style: .continuous)
                                .stroke(TeaPulseTheme.error.opacity(0.4), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(TeaPulsePressableCardStyle())
                    .padding(.horizontal, TeaPulseSpacing.md)
                    .padding(.top, TeaPulseSpacing.sm)
                    Spacer()
                }
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                .task(id: banner.id) {
                    try? await Task.sleep(for: .seconds(5))
                    if store.simulatedPushBanner?.id == banner.id {
                        TeaPulseMotion.run(TeaPulseMotion.spring, reduceMotion: reduceMotion) {
                            store.simulatedPushBanner = nil
                        }
                    }
                }
            }

            if store.isResolvingRoute && store.simulatedPushBanner == nil {
                VStack {
                    HStack(spacing: TeaPulseSpacing.sm) {
                        ProgressView()
                            .tint(TeaPulseTheme.primary)
                        Text("正在加载目标内容…")
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, TeaPulseSpacing.md)
                    .padding(.vertical, TeaPulseSpacing.sm)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
                    .padding(.top, TeaPulseSpacing.sm)
                    Spacer()
                }
                .allowsHitTesting(false)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }

            if let toast = store.statusToast {
                HStack(spacing: TeaPulseSpacing.sm) {
                    Image(systemName: store.statusToastTone.iconName)
                        .foregroundStyle(toastAccentColor)
                    Text(toast)
                        .font(TeaPulseTypography.bodySm)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                        .lineLimit(1)
                }
                .padding(.horizontal, TeaPulseSpacing.md)
                .padding(.vertical, TeaPulseSpacing.sm)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(toastBorderColor, lineWidth: 1))
                .padding(.bottom, useCompactShell ? 64 : TeaPulseSpacing.lg)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .task(id: toast) {
                    try? await Task.sleep(for: .seconds(2.2))
                    if store.statusToast == toast {
                        TeaPulseMotion.run(TeaPulseMotion.spring, reduceMotion: reduceMotion) {
                            store.statusToast = nil
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .background {
            HStack(spacing: 0) {
                Button("") {
                    store.isCommandPalettePresented = true
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("") {
                    Task { await store.refreshLiveInstanceData() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            .frame(width: 0, height: 0)
            .opacity(0.001)
            .accessibilityHidden(true)
        }
        #endif
        .animation(reduceMotion ? nil : TeaPulseMotion.spring, value: store.simulatedPushBanner?.id)
        .animation(reduceMotion ? nil : TeaPulseMotion.spring, value: store.isResolvingRoute)
        .animation(reduceMotion ? nil : TeaPulseMotion.spring, value: store.statusToast)
        .background(TeaPulseTheme.surface.ignoresSafeArea())
        .tint(TeaPulseTheme.primary)
        #if os(macOS)
        .frame(minWidth: 980, minHeight: 680)
        #endif
        .sheet(isPresented: $bindableStore.isCommandPalettePresented) {
            CommandPaletteView()
                .preferredColorScheme(store.themePreference.colorScheme)
        }
        .sheet(isPresented: $bindableStore.isConnectionSheetPresented) {
            InstanceConnectionSheet()
                .preferredColorScheme(store.themePreference.colorScheme)
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $bindableStore.isLoginGatePresented) {
            InstanceOnboardingView()
                .preferredColorScheme(store.themePreference.colorScheme)
        }
        #else
        .sheet(isPresented: $bindableStore.isLoginGatePresented) {
            InstanceOnboardingView()
                .frame(minWidth: 560, idealWidth: 580, minHeight: 640, idealHeight: 700)
                .preferredColorScheme(store.themePreference.colorScheme)
        }
        #endif
    }

    private var compactTabShell: some View {
        @Bindable var bindableStore = store
        return TabView(selection: $bindableStore.selectedSection) {
            NavigationStack {
                PulseDashboardView()
            }
            .tabItem { Label(AppSection.pulse.title, systemImage: AppSection.pulse.systemImage) }
            .tag(AppSection.pulse)

            NavigationStack {
                RepositoryListView()
            }
            .tabItem { Label(AppSection.repos.title, systemImage: AppSection.repos.systemImage) }
            .tag(AppSection.repos)

            NavigationStack {
                ActionsWorkspaceView()
            }
            .tabItem { Label(AppSection.actions.title, systemImage: AppSection.actions.systemImage) }
            .tag(AppSection.actions)

            NavigationStack {
                InboxWorkspaceView()
            }
            .badge(store.unreadInboxCount)
            .tabItem { Label(AppSection.inbox.title, systemImage: AppSection.inbox.systemImage) }
            .tag(AppSection.inbox)

            NavigationStack {
                OpsWorkspaceView()
            }
            .tabItem { Label(AppSection.ops.title, systemImage: AppSection.ops.systemImage) }
            .tag(AppSection.ops)
        }
    }

    private var splitWorkspaceShell: some View {
        @Bindable var bindableStore = store
        return NavigationSplitView(columnVisibility: $columnVisibility) {
            let badge = store.health.sidebarVersionBadge
            VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
                HStack(spacing: TeaPulseSpacing.sm) {
                    HStack(spacing: TeaPulseSpacing.xs) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(TeaPulseTheme.primary)
                        Text("TeaPulse")
                            .font(TeaPulseTypography.headlineMd)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    Spacer(minLength: TeaPulseSpacing.xs)
                    StatusBadge(badge.label, tone: badge.tone)
                }
                .padding(.horizontal, TeaPulseSpacing.md)
                .padding(.top, TeaPulseSpacing.md)

                EndpointProbePill(health: store.health, fullWidth: true) {
                    store.isConnectionSheetPresented = true
                }
                .padding(.horizontal, TeaPulseSpacing.md)

                VStack(spacing: TeaPulseSpacing.xs) {
                    ForEach(AppSection.allCases) { section in
                        let isSelected = store.selectedSection == section
                        Button {
                            TeaPulseMotion.run(TeaPulseMotion.snappy, reduceMotion: reduceMotion) {
                                store.selectedSection = section
                            }
                        } label: {
                            HStack(spacing: TeaPulseSpacing.sm) {
                                Image(systemName: section.systemImage)
                                    .foregroundStyle(isSelected ? TeaPulseTheme.onPrimary : TeaPulseTheme.secondary)
                                    .frame(width: 20)
                                Text(section.title)
                                    .font(TeaPulseTypography.bodyMd)
                                    .fontWeight(isSelected ? .semibold : .regular)
                                    .foregroundStyle(isSelected ? TeaPulseTheme.onPrimary : TeaPulseTheme.onSurface)
                                Spacer()
                                if section == .inbox && store.unreadInboxCount > 0 {
                                    if isSelected {
                                        Text("\(store.unreadInboxCount)")
                                            .font(TeaPulseTypography.codeSm)
                                            .monospacedDigit()
                                            .foregroundStyle(TeaPulseTheme.onPrimary)
                                            .padding(.horizontal, TeaPulseSpacing.sm)
                                            .padding(.vertical, TeaPulseSpacing.xs)
                                            .background(TeaPulseTheme.primaryHover)
                                            .clipShape(Capsule(style: .continuous))
                                            .teaPulseNumericTransition(value: store.unreadInboxCount)
                                    } else {
                                        StatusBadge("\(store.unreadInboxCount)", tone: .primary)
                                            .teaPulseNumericTransition(value: store.unreadInboxCount)
                                    }
                                }
                            }
                            .padding(.horizontal, TeaPulseSpacing.md)
                            .padding(.vertical, TeaPulseSpacing.sm)
                            .frame(minHeight: 40)
                            .background(isSelected ? TeaPulseTheme.primaryAction : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(TeaPulsePressableCardStyle())
                    }
                }
                .padding(.horizontal, TeaPulseSpacing.md)

                Spacer()

                VStack(spacing: TeaPulseSpacing.sm) {
                    TeaPulseThemeSwitcher(selection: $bindableStore.themePreference)

                    Button {
                        bindableStore.isCommandPalettePresented = true
                    } label: {
                        HStack(spacing: TeaPulseSpacing.sm) {
                            Image(systemName: "command")
                                .foregroundStyle(TeaPulseTheme.secondary)
                            Text("命令面板 ⌘K")
                                .font(TeaPulseTypography.bodySm)
                                .foregroundStyle(TeaPulseTheme.onSurface)
                            Spacer()
                        }
                        .padding(.horizontal, TeaPulseSpacing.md)
                        .padding(.vertical, TeaPulseSpacing.sm)
                        .frame(minHeight: 36)
                        .background(TeaPulseTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(TeaPulsePressableCardStyle())
                }
                .padding(.horizontal, TeaPulseSpacing.md)
                .padding(.bottom, TeaPulseSpacing.md)
            }
            .navigationSplitViewColumnWidth(min: 228, ideal: 244, max: 276)
            .background(TeaPulseTheme.surfaceCard)
        } detail: {
            splitWorkspaceBody
                .animation(reduceMotion ? nil : TeaPulseMotion.snappy, value: store.selectedSection)
        }
    }

    @ViewBuilder
    private var splitWorkspaceBody: some View {
        if store.selectedSection.usesMasterDetailSplit {
            HStack(spacing: 0) {
                middleListColumnView
                    .frame(width: 340)
                    .frame(maxHeight: .infinity)
                    .background(TeaPulseTheme.surface)

                Rectangle()
                    .fill(TeaPulseTheme.cardBorder)
                    .frame(width: 1)
                    .ignoresSafeArea()

                NavigationStack {
                    masterDetailRightView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(TeaPulseTheme.surface)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            NavigationStack {
                singleCanvasSectionView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(TeaPulseTheme.surface)
            }
        }
    }

    @ViewBuilder
    private var singleCanvasSectionView: some View {
        switch store.selectedSection {
        case .pulse:
            PulseDashboardView()
        case .inbox:
            InboxWorkspaceView()
        case .ops:
            OpsWorkspaceView()
        case .repos, .actions:
            EmptyView()
        }
    }

    @ViewBuilder
    private var middleListColumnView: some View {
        switch store.selectedSection {
        case .repos:
            RepositoryListView()
        case .actions:
            ActionsWorkspaceView()
        case .pulse, .inbox, .ops:
            EmptyView()
        }
    }

    @ViewBuilder
    private var masterDetailRightView: some View {
        switch store.selectedSection {
        case .repos:
            if let pr = store.selectedPullRequest, store.selectedRepoTab == .pullRequests {
                PullRequestWorkspaceView(pullRequest: pr)
            } else if let repo = store.selectedRepository {
                RepositoryWorkspaceView(repository: repo)
            } else {
                SplitEmptyDetailView(
                    icon: "folder.badge.gearshape",
                    title: "选择一个仓库",
                    subtitle: "从左侧列表选择仓库以查看概览、源码目录、合并请求与运维设置"
                )
            }
        case .actions:
            if store.actionsFilter == .runners {
                RunnersMonitorView()
            } else if let run = store.selectedRun {
                ANSITerminalLogView(run: run)
            } else {
                SplitEmptyDetailView(
                    icon: "terminal",
                    title: "选择一条工作流记录",
                    subtitle: "从左侧列表点击构建任务以查看步骤耗时与终端日志"
                )
            }
        case .pulse, .inbox, .ops:
            EmptyView()
        }
    }

    private var toastAccentColor: Color {
        switch store.statusToastTone {
        case .success: return TeaPulseTheme.primary
        case .warning: return TeaPulseTheme.warning
        case .error: return TeaPulseTheme.error
        }
    }

    private var toastBorderColor: Color {
        switch store.statusToastTone {
        case .success: return TeaPulseTheme.cardBorder
        case .warning: return TeaPulseTheme.warning.opacity(0.45)
        case .error: return TeaPulseTheme.error.opacity(0.45)
        }
    }
}

private struct SplitEmptyDetailView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: TeaPulseSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(TeaPulseTheme.secondary)
            Text(title)
                .font(TeaPulseTypography.headlineMd)
                .foregroundStyle(TeaPulseTheme.onSurface)
            Text(subtitle)
                .font(TeaPulseTypography.bodySm)
                .foregroundStyle(TeaPulseTheme.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .padding(TeaPulseSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
