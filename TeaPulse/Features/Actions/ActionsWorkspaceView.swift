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
                    RunnersMonitorView()
                } else {
                    VStack(spacing: TeaPulseSpacing.md) {
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
                                SurfaceCard {
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
            EndpointProbePill(health: store.health) {
                store.isConnectionSheetPresented = true
            }
        }
    }
}
