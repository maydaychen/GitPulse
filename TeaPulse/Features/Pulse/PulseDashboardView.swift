import SwiftUI
import GiteaKit

public struct PulseDashboardView: View {
    @Environment(AppStore.self) private var store

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.lg) {
                headerRow
                    .teaPulseStaggeredReveal(index: 0)
                triageSection
                    .teaPulseStaggeredReveal(index: 1)
                pinnedReposSection
                    .teaPulseStaggeredReveal(index: 2)
                HeatmapGridView(
                    days: store.heatmap,
                    onlineRunners: store.runners.filter { $0.status != .offline }.count,
                    totalRunners: store.runners.count,
                    isLoading: store.isInitialWorkspaceLoading
                )
                .teaPulseStaggeredReveal(index: 3)
                activitySection
                    .teaPulseStaggeredReveal(index: 4)
            }
            .padding(.horizontal, TeaPulseSpacing.md)
            .padding(.vertical, TeaPulseSpacing.md)
        }
        .background(TeaPulseTheme.surface)
        .refreshable {
            await store.refreshLiveInstanceData()
        }
    }

    private var headerRow: some View {
        HStack(spacing: TeaPulseSpacing.sm) {
            Text("概览")
                .font(TeaPulseTypography.headlineLg)
                .foregroundStyle(TeaPulseTheme.onSurface)
                .lineLimit(1)

            Spacer(minLength: TeaPulseSpacing.sm)

            Button {
                store.isCommandPalettePresented = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(TeaPulseTypography.bodySm)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .frame(width: 36, height: 36)
                    .background(TeaPulseTheme.surfaceElevated)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(TeaPulsePressableCardStyle())

            EndpointProbePill(health: store.health) {
                store.isConnectionSheetPresented = true
            }
        }
    }

    private var triageSection: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
            HStack {
                Text("优先队列")
                    .font(TeaPulseTypography.labelMd)
                    .foregroundStyle(TeaPulseTheme.secondary)
                Spacer()
                Text("\(store.triage.count) 项")
                    .font(TeaPulseTypography.codeSm)
                    .monospacedDigit()
                    .foregroundStyle(TeaPulseTheme.secondary)
                    .teaPulseNumericTransition(value: store.triage.count)
            }

            if store.triage.isEmpty {
                if store.isInitialWorkspaceLoading {
                    LoadingStateCard("正在加载优先事项…")
                } else {
                    SurfaceCard {
                        Text("当前无待处理的优先事项")
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                VStack(spacing: TeaPulseSpacing.md) {
                    ForEach(store.triage) { item in
                        Button {
                            openTriage(item)
                        } label: {
                            SurfaceCard {
                                VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                                    HStack(spacing: TeaPulseSpacing.sm) {
                                        StatusBadge(triageLabel(item.kind), tone: triageTone(item.kind))
                                        Spacer()
                                        Text(item.metricText)
                                            .font(TeaPulseTypography.codeSm)
                                            .monospacedDigit()
                                            .foregroundStyle(triageMetricColor(item.kind))
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }

                                    Text(item.repoFullName)
                                        .font(TeaPulseTypography.codeSm)
                                        .foregroundStyle(TeaPulseTheme.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    Text(item.title)
                                        .font(TeaPulseTypography.bodyMd)
                                        .foregroundStyle(TeaPulseTheme.onSurface)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if !item.subtitlePill.isEmpty {
                                        BranchRoutePill(item.subtitlePill)
                                            .padding(.top, 2)
                                    }
                                }
                            }
                        }
                        .buttonStyle(TeaPulsePressableCardStyle())
                    }
                }
            }
        }
    }

    private var pinnedReposSection: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
            Text("置顶仓库")
                .font(TeaPulseTypography.labelMd)
                .foregroundStyle(TeaPulseTheme.secondary)

            if store.pinnedRepos.isEmpty {
                if store.isInitialWorkspaceLoading {
                    LoadingStateCard("正在加载置顶仓库…")
                } else {
                    SurfaceCard {
                        Text("暂无置顶仓库")
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: TeaPulseSpacing.md),
                        GridItem(.flexible(), spacing: TeaPulseSpacing.md)
                    ],
                    spacing: TeaPulseSpacing.md
                ) {
                    ForEach(store.pinnedRepos) { repo in
                        Button {
                            store.handle(deepLinkString: "teapulse://repo/\(repo.fullName)")
                        } label: {
                            SurfaceCard {
                                VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                                    HStack(spacing: TeaPulseSpacing.xs) {
                                        PulsingStatusDot(
                                            color: repo.ciStatus == .failure
                                                ? TeaPulseTheme.error
                                                : (repo.ciStatus == .waitingApproval ? TeaPulseTheme.warning : TeaPulseTheme.primary),
                                            animate: repo.ciStatus == .running
                                        )
                                        Text(repo.fullName)
                                            .font(TeaPulseTypography.bodySm)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(TeaPulseTheme.onSurface)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }

                                    HStack(spacing: TeaPulseSpacing.xs) {
                                        BranchRoutePill(repo.defaultBranch)
                                        if repo.isMirror {
                                            StatusBadge("镜像", tone: .neutral)
                                        }
                                        Spacer()
                                    }

                                    if !repo.isMirror {
                                        Text("\(repo.openPRCount) 合并请求")
                                            .font(TeaPulseTypography.codeSm)
                                            .monospacedDigit()
                                            .foregroundStyle(TeaPulseTheme.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .buttonStyle(TeaPulsePressableCardStyle())
                        .contextMenu {
                            Button(store.isRepositoryPinned(repo.fullName) ? "取消置顶" : "置顶到首页") {
                                store.togglePinRepository(repo.fullName)
                            }
                        }
                    }
                }
            }
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
            Text("实例动态")
                .font(TeaPulseTypography.labelMd)
                .foregroundStyle(TeaPulseTheme.secondary)

            if store.activities.isEmpty {
                if store.isInitialWorkspaceLoading {
                    LoadingStateCard("正在加载实例动态…")
                } else {
                    SurfaceCard {
                        Text("暂无实例动态")
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                SurfaceCard {
                    VStack(spacing: 0) {
                        ForEach(Array(store.activities.enumerated()), id: \.element.id) { index, act in
                            if index > 0 {
                                Divider()
                                    .overlay(TeaPulseTheme.cardBorder)
                            }
                            Button {
                                store.handle(deepLinkString: act.deepLink)
                            } label: {
                                VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                                    HStack(spacing: TeaPulseSpacing.sm) {
                                        Text(act.actor)
                                            .font(TeaPulseTypography.codeSm)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(TeaPulseTheme.primary)
                                            .lineLimit(1)
                                        Spacer()
                                        Text(act.timestampText)
                                            .font(TeaPulseTypography.codeSm)
                                            .monospacedDigit()
                                            .foregroundStyle(TeaPulseTheme.secondary)
                                        if !act.deepLink.isEmpty {
                                            Image(systemName: "chevron.right")
                                                .font(TeaPulseTypography.codeSm)
                                                .foregroundStyle(TeaPulseTheme.secondary)
                                        }
                                    }

                                    Text(act.actionLabel)
                                        .font(TeaPulseTypography.bodyMd)
                                        .foregroundStyle(TeaPulseTheme.onSurface)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if !act.repoFullName.isEmpty || !act.refText.isEmpty {
                                        HStack(spacing: TeaPulseSpacing.sm) {
                                            if !act.repoFullName.isEmpty {
                                                Text(act.repoFullName)
                                                    .font(TeaPulseTypography.codeSm)
                                                    .foregroundStyle(TeaPulseTheme.secondary)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            }
                                            Spacer()
                                            if !act.refText.isEmpty {
                                                BranchRoutePill(act.refText)
                                            }
                                        }
                                        .padding(.top, 2)
                                    }
                                }
                                .padding(.vertical, TeaPulseSpacing.sm)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(TeaPulsePressableCardStyle())
                        }
                    }
                }
            }
        }
    }

    private func openTriage(_ item: TriageItem) {
        store.handle(deepLinkString: item.deepLink)
    }

    private func triageLabel(_ kind: TriageKind) -> String {
        switch kind {
        case .pullRequest: return "待审合并"
        case .failedRun: return "构建失败"
        case .offlineRunner: return "节点告警"
        }
    }

    private func triageTone(_ kind: TriageKind) -> StatusBadge.Tone {
        switch kind {
        case .pullRequest: return .primary
        case .failedRun: return .error
        case .offlineRunner: return .warning
        }
    }

    private func triageMetricColor(_ kind: TriageKind) -> Color {
        switch kind {
        case .pullRequest: return TeaPulseTheme.primary
        case .failedRun: return TeaPulseTheme.error
        case .offlineRunner: return TeaPulseTheme.warning
        }
    }
}
