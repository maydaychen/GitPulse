import SwiftUI
import GiteaKit

public struct ActionsWorkspaceView: View {
    @Environment(AppStore.self) private var store
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @State private var pushedRun: WorkflowRun?

    private var shouldPushInStack: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.lg) {
                headerRow

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: TeaPulseSpacing.sm) {
                        ForEach(ActionsFilterScope.allCases) { scope in
                            FilterChipButton(
                                title: scope.rawValue,
                                isSelected: store.actionsFilter == scope
                            ) {
                                store.actionsFilter = scope
                            }
                        }
                    }
                }

                if store.actionsFilter == .runners {
                    if shouldPushInStack {
                        RunnersMonitorView()
                    } else {
                        splitRunnerSummaryPane
                    }
                } else {
                    LazyVStack(spacing: TeaPulseSpacing.md) {
                        if store.filteredRuns.isEmpty {
                            if store.isInitialWorkspaceLoading || store.isResolvingRoute {
                                LoadingStateCard("正在加载工作流运行记录…")
                            } else {
                                SurfaceCard {
                                    Text("当前筛选条件下暂无工作流运行记录")
                                        .font(TeaPulseTypography.bodySm)
                                        .foregroundStyle(TeaPulseTheme.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }

                        ForEach(store.filteredRuns) { run in
                            Button {
                                store.selectedRunID = run.id
                                if shouldPushInStack {
                                    pushedRun = run
                                }
                            } label: {
                                SurfaceCard(isSelected: !shouldPushInStack && store.selectedRunID == run.id) {
                                    VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                                        HStack(spacing: TeaPulseSpacing.sm) {
                                            StatusBadge(run.status.badgeLabel, tone: run.status.badgeTone)
                                            Text(run.repoFullName)
                                                .font(TeaPulseTypography.codeSm)
                                                .foregroundStyle(TeaPulseTheme.secondary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                            Spacer()
                                            Text(run.durationText)
                                                .font(TeaPulseTypography.codeSm)
                                                .monospacedDigit()
                                                .foregroundStyle(TeaPulseTheme.secondary)
                                        }
                                        Text("\(run.workflowName) #\(run.runNumber)")
                                            .font(TeaPulseTypography.bodyMd)
                                            .foregroundStyle(TeaPulseTheme.onSurface)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        HStack(spacing: TeaPulseSpacing.sm) {
                                            BranchRoutePill(run.branch)
                                            Text(run.runnerName)
                                                .font(TeaPulseTypography.codeSm)
                                                .foregroundStyle(TeaPulseTheme.secondary)
                                                .lineLimit(1)
                                            Spacer()
                                        }
                                    }
                                }
                            }
                            .buttonStyle(TeaPulsePressableCardStyle())
                        }
                    }
                }
            }
            .padding(TeaPulseSpacing.md)
        }
        .background(TeaPulseTheme.surface)
        .refreshable {
            await store.refreshLiveInstanceData()
        }
        .navigationDestination(item: $pushedRun) { run in
            ANSITerminalLogView(run: run)
        }
        .onChange(of: store.routeNavigationID, initial: true) { _, requestID in
            guard requestID > 0, shouldPushInStack, store.selectedSection == .actions else { return }
            pushedRun = store.actionsFilter == .runners ? nil : store.selectedRun
        }
    }

    private var headerRow: some View {
        HStack(spacing: TeaPulseSpacing.sm) {
            Text("工作流")
                .font(TeaPulseTypography.headlineLg)
                .foregroundStyle(TeaPulseTheme.onSurface)
                .lineLimit(1)
            Spacer()
            if shouldPushInStack {
                EndpointProbePill(health: store.health) {
                    store.isConnectionSheetPresented = true
                }
            }
        }
    }

    private var splitRunnerSummaryPane: some View {
        let onlineCount = store.runners.filter { $0.status == .online }.count
        let busyCount = store.runners.filter { $0.status == .busy }.count
        let offlineCount = store.runners.filter { $0.status == .offline }.count

        return VStack(spacing: TeaPulseSpacing.md) {
            SurfaceCard(isSelected: true) {
                VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                    HStack(spacing: TeaPulseSpacing.sm) {
                        StatusBadge("在线 \(onlineCount)", tone: .primary)
                        StatusBadge("执行中 \(busyCount)", tone: .warning)
                        if offlineCount > 0 {
                            StatusBadge("离线 \(offlineCount)", tone: .error)
                        }
                        Spacer()
                    }
                    Text("右侧已展开执行节点池详情与注册令牌管理")
                        .font(TeaPulseTypography.bodySm)
                        .foregroundStyle(TeaPulseTheme.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            ForEach(store.runners) { runner in
                SurfaceCard {
                    HStack(spacing: TeaPulseSpacing.sm) {
                        PulsingStatusDot(
                            color: runner.status == .online ? TeaPulseTheme.primary : (runner.status == .busy ? TeaPulseTheme.warning : TeaPulseTheme.error),
                            animate: runner.status != .offline
                        )
                        VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                            Text(runner.name)
                                .font(TeaPulseTypography.bodySm)
                                .fontWeight(.semibold)
                                .foregroundStyle(TeaPulseTheme.onSurface)
                                .lineLimit(1)
                            Text(runner.hostLabel)
                                .font(TeaPulseTypography.codeSm)
                                .foregroundStyle(TeaPulseTheme.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        StatusBadge(
                            runner.status.badgeLabel,
                            tone: runner.status == .online ? .primary : (runner.status == .busy ? .warning : .error)
                        )
                    }
                }
            }
        }
    }
}
