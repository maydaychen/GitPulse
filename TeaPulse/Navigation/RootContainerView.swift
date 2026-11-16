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
                .frame(minWidth: 540, minHeight: 680)
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
            VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
                HStack(spacing: TeaPulseSpacing.sm) {
                    Text("TeaPulse")
                        .font(TeaPulseTypography.headlineMd)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                    Spacer()
                    StatusBadge(store.health.serverVersion, tone: .primary)
                }
                .padding(.horizontal, TeaPulseSpacing.md)
                .padding(.top, TeaPulseSpacing.md)

                EndpointProbePill(health: store.health) {
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

                Picker("外观", selection: $bindableStore.themePreference) {
                    ForEach(ThemePreference.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, TeaPulseSpacing.md)

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
                .padding(TeaPulseSpacing.md)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
            .background(TeaPulseTheme.surfaceCard)
        } content: {
            middleColumnView
                .animation(reduceMotion ? nil : TeaPulseMotion.snappy, value: store.selectedSection)
                .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 400)
                .background(TeaPulseTheme.surface)
        } detail: {
            NavigationStack {
                detailColumnView
                    .animation(reduceMotion ? nil : TeaPulseMotion.snappy, value: store.selectedSection)
                    .background(TeaPulseTheme.surface)
            }
        }
    }

    @ViewBuilder
    private var middleColumnView: some View {
        switch store.selectedSection {
        case .pulse:
            PulseDashboardView()
        case .repos:
            RepositoryListView()
        case .actions:
            ActionsWorkspaceView()
        case .inbox:
            InboxWorkspaceView()
        case .ops:
            OpsWorkspaceView()
        }
    }

    @ViewBuilder
    private var detailColumnView: some View {
        switch store.selectedSection {
        case .pulse:
            if let pr = store.selectedPullRequest {
                PullRequestWorkspaceView(pullRequest: pr)
            } else if let repo = store.selectedRepository {
                RepositoryWorkspaceView(repository: repo)
            } else {
                PulseDashboardView()
            }
        case .repos:
            if let pr = store.selectedPullRequest, store.selectedRepoTab == .pullRequests {
                PullRequestWorkspaceView(pullRequest: pr)
            } else if let repo = store.selectedRepository {
                RepositoryWorkspaceView(repository: repo)
            } else {
                Text("选择仓库")
                    .font(TeaPulseTypography.bodyMd)
                    .foregroundStyle(TeaPulseTheme.secondary)
            }
        case .actions:
            if store.actionsFilter == .runners {
                RunnersMonitorView()
            } else if let run = store.selectedRun {
                ANSITerminalLogView(run: run)
            } else {
                RunnersMonitorView()
            }
        case .inbox:
            if let pr = store.selectedPullRequest {
                PullRequestWorkspaceView(pullRequest: pr)
            } else if let run = store.selectedRun {
                ANSITerminalLogView(run: run)
            } else {
                InboxWorkspaceView()
            }
        case .ops:
            OpsWorkspaceView()
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
