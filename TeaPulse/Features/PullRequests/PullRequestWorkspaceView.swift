import SwiftUI
import GiteaKit

public struct PullRequestWorkspaceView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    public let pullRequest: PullRequestDetail

    @State private var mergeStrategy: PRMergeStrategy = .squash
    @State private var reviewComment = ""

    public init(pullRequest: PullRequestDetail) {
        self.pullRequest = pullRequest
    }

    private var livePR: PullRequestDetail {
        store.pullRequests.first(where: { $0.id == pullRequest.id }) ?? pullRequest
    }

    private var isPRLoading: Bool {
        store.isLoadingPRDetails(livePR) || store.isLoadingRepoDetails(livePR.repoFullName)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: TeaPulseSpacing.lg) {
                    #if os(macOS)
                    if store.selectedSection == .repos && store.selectedRepository != nil {
                        HStack {
                            Button {
                                TeaPulseMotion.run(TeaPulseMotion.snappy, reduceMotion: reduceMotion) {
                                    store.selectedPRID = nil
                                }
                            } label: {
                                Label("返回 \(livePR.repoFullName)", systemImage: "chevron.left")
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                            Spacer()
                        }
                    }
                    #endif
                    stickyHeader
                    if let pos = livePR.stackPosition, let total = livePR.stackTotal {
                        stackedTrainBar(position: pos, total: total)
                    }

                    Picker("合并请求分栏", selection: Binding(
                        get: { store.selectedPRSegment },
                        set: { next in TeaPulseMotion.run(TeaPulseMotion.snappy, reduceMotion: reduceMotion) { store.selectedPRSegment = next } }
                    )) {
                        ForEach(PullRequestSegment.allCases) { seg in
                            Text(seg.rawValue).tag(seg)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    Group {
                        switch store.selectedPRSegment {
                        case .overview:
                            overviewSection
                        case .diff:
                            DiffReaderView(prID: livePR.id, files: livePR.files, comments: livePR.comments, isLoading: isPRLoading)
                        case .checks:
                            checksSection
                        }
                    }
                    .animation(reduceMotion ? nil : TeaPulseMotion.snappy, value: store.selectedPRSegment)

                    Spacer(minLength: 88)
                }
                .padding(TeaPulseSpacing.md)
            }
            .background(TeaPulseTheme.surface)
            .refreshable {
                await store.reloadPullRequestDetails(livePR)
            }

            if livePR.state == .open {
                floatingMergeDock
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : TeaPulseMotion.spring, value: livePR.state)
        .task(id: livePR.id) {
            await store.loadPullRequestDetails(livePR)
        }
    }

    private var stickyHeader: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                HStack(spacing: TeaPulseSpacing.sm) {
                    StatusBadge(livePR.state == .merged ? "已合并" : "合并请求 #\(livePR.number)", tone: livePR.state == .merged ? .tertiary : .primary)
                    Spacer()
                    Text("+\(livePR.additions) -\(livePR.deletions)")
                        .font(TeaPulseTypography.codeSm)
                        .monospacedDigit()
                        .foregroundStyle(TeaPulseTheme.primary)
                }

                Text(livePR.repoFullName)
                    .font(TeaPulseTypography.codeSm)
                    .foregroundStyle(TeaPulseTheme.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(livePR.title)
                    .font(TeaPulseTypography.headlineMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    BranchRoutePill(livePR.branchRouteLabel)
                    Spacer()
                    Text("@\(livePR.author)")
                        .font(TeaPulseTypography.codeSm)
                        .foregroundStyle(TeaPulseTheme.secondary)
                }
            }
        }
    }

    private func stackedTrainBar(position: Int, total: Int) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                HStack(spacing: TeaPulseSpacing.sm) {
                    StatusBadge("堆叠 \(position)/\(total)", tone: .tertiary)
                    BranchRoutePill(livePR.baseBranch)
                    Spacer()
                }
                Text("合并后自动推进下游基底")
                    .font(TeaPulseTypography.labelMd)
                    .foregroundStyle(TeaPulseTheme.secondary)
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                    TextField("评审意见或回复…", text: $reviewComment)
                        .textFieldStyle(.plain)
                        .font(TeaPulseTypography.bodySm)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                        .padding(TeaPulseSpacing.sm)
                        .background(TeaPulseTheme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))

                    HStack(spacing: TeaPulseSpacing.sm) {
                        Button("仅评论") {
                            Task {
                                if await store.submitPRReview(prID: livePR.id, decision: .comment, summary: reviewComment) {
                                    reviewComment = ""
                                }
                            }
                        }
                        .buttonStyle(SecondaryActionButtonStyle())

                        Button("请求修改") {
                            Task {
                                if await store.submitPRReview(prID: livePR.id, decision: .requestChanges, summary: reviewComment) {
                                    reviewComment = ""
                                }
                            }
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }

            if livePR.comments.isEmpty {
                if isPRLoading {
                    LoadingStateCard("正在加载评审评论…")
                } else {
                    SurfaceCard {
                        Text("暂无评审评论，可在上方提交总结或在代码对比中点击行号添加批注")
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            ForEach(livePR.comments) { comment in
                SurfaceCard {
                    VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                        HStack {
                            Text("@\(comment.author)")
                                .font(TeaPulseTypography.codeSm)
                                .foregroundStyle(TeaPulseTheme.primary)
                            Spacer()
                            Text(comment.timestampText)
                                .font(TeaPulseTypography.codeSm)
                                .foregroundStyle(TeaPulseTheme.secondary)
                        }
                        if let path = comment.filePath, let line = comment.lineNumber {
                            StatusBadge("\(path):\(line)", tone: .neutral)
                        }
                        Text(comment.body)
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var checksSection: some View {
        VStack(spacing: TeaPulseSpacing.sm) {
            if livePR.checks.isEmpty {
                if isPRLoading {
                    LoadingStateCard("正在加载 CI 检查状态…")
                } else {
                    SurfaceCard {
                        Text("当前合并请求暂无 CI 检查状态")
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            ForEach(livePR.checks) { check in
                Button {
                    store.handle(deepLinkString: check.deepLink)
                } label: {
                    SurfaceCard {
                        HStack(spacing: TeaPulseSpacing.sm) {
                            StatusBadge(check.status.badgeLabel, tone: check.status.badgeTone)
                            Text(check.name)
                                .font(TeaPulseTypography.bodySm)
                                .foregroundStyle(TeaPulseTheme.onSurface)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Text(check.durationText)
                                .font(TeaPulseTypography.codeSm)
                                .monospacedDigit()
                                .foregroundStyle(TeaPulseTheme.secondary)
                        }
                    }
                }
                .buttonStyle(TeaPulsePressableCardStyle())
            }
        }
    }

    private var floatingMergeDock: some View {
        let isApproved = store.approvedPRIDs.contains(livePR.id)
        return HStack(spacing: TeaPulseSpacing.sm) {
            TeaPulseDropdownMenu(
                items: PRMergeStrategy.allCases.map { strategy in
                    TeaPulseDropdownItem(
                        value: strategy,
                        title: strategy.label,
                        icon: mergeStrategyIcon(for: strategy)
                    )
                },
                selection: $mergeStrategy,
                preferredColorScheme: store.themePreference.colorScheme
            )

            Button(isApproved ? "已批准" : "批准") {
                Task {
                    await store.toggleApprovePR(livePR.id)
                }
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .animation(reduceMotion ? nil : TeaPulseMotion.spring, value: isApproved)

            Spacer(minLength: TeaPulseSpacing.xs)

            Button("合并") {
                Task {
                    if await store.mergePullRequest(prID: livePR.id, strategy: mergeStrategy) {
                        reviewComment = ""
                    }
                }
            }
            .buttonStyle(PrimaryActionButtonStyle())
        }
        .padding(.horizontal, TeaPulseSpacing.md)
        .padding(.vertical, TeaPulseSpacing.sm)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
        .padding(.horizontal, TeaPulseSpacing.md)
        .padding(.bottom, TeaPulseSpacing.sm)
    }

    private func mergeStrategyIcon(for strategy: PRMergeStrategy) -> String {
        switch strategy {
        case .squash: return "square.stack.3d.up"
        case .merge: return "arrow.triangle.merge"
        case .rebase: return "arrow.triangle.branch"
        }
    }
}
