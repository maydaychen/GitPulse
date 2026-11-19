import SwiftUI
import GiteaKit

public struct RepositoryWorkspaceView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    public let repository: RepositorySummary

    @State private var pushedPR: PullRequestDetail?
    @State private var pushedFile: RepoFileEntry?
    @State private var pushedCommit: RepoCommitItem?
    @State private var currentDirectoryPath = ""
    @State private var loadedRepositoryID = ""
    @State private var isLoadingDetails = false
    @State private var showCloneSheet = false
    @State private var showBranchSheet = false
    @State private var prDisplayMode: PRDisplayMode = .list

    private enum PRDisplayMode: String, CaseIterable, Identifiable {
        case list = "列表"
        case stacks = "堆叠链"
        var id: String { rawValue }
    }

    private var shouldPushInStack: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }

    public init(repository: RepositorySummary) {
        self.repository = repository
    }

    private var liveRepo: RepositorySummary {
        store.repositories.first { $0.id == repository.id }
            ?? store.repository(named: repository.fullName)
            ?? repository
    }

    private func lookup<T>(_ dict: [String: [T]]) -> [T] {
        dict[store.canonicalRepoName(liveRepo.fullName)]
            ?? dict.first { $0.key.caseInsensitiveCompare(liveRepo.fullName) == .orderedSame }?.value
            ?? []
    }

    private var repoPRs: [PullRequestDetail] {
        store.pullRequests.filter { $0.repoFullName.caseInsensitiveCompare(liveRepo.fullName) == .orderedSame }
    }

    private var files: [RepoFileEntry] { lookup(store.repoFiles) }

    private var branches: [RepoBranchItem] { lookup(store.branchesByRepo) }

    private var commits: [RepoCommitItem] { lookup(store.commitsByRepo) }

    private var issues: [IssueItem] { lookup(store.issuesByRepo) }

    private var kanban: [KanbanCard] { lookup(store.kanbanByRepo) }

    private var isRepoLoading: Bool { isLoadingDetails || store.isLoadingRepoDetails(liveRepo.fullName) }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.lg) {
                stickySummaryHeader

                Picker("仓库分栏", selection: Binding(
                    get: { store.selectedRepoTab },
                    set: { next in TeaPulseMotion.run(TeaPulseMotion.snappy, reduceMotion: reduceMotion) { store.selectedRepoTab = next } }
                )) {
                    ForEach(RepoWorkspaceTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                tabContent
                    .animation(reduceMotion ? nil : TeaPulseMotion.snappy, value: store.selectedRepoTab)
            }
            .padding(TeaPulseSpacing.md)
        }
        .background(TeaPulseTheme.surface)
        .refreshable {
            await store.loadRepositoryTabIfNeeded(
                repoFullName: liveRepo.fullName,
                tab: store.selectedRepoTab,
                directoryPath: currentDirectoryPath,
                force: true
            )
        }
        .task(id: "\(repository.id)::\(store.selectedRepoTab.rawValue)") {
            if loadedRepositoryID != repository.id {
                loadedRepositoryID = repository.id
                currentDirectoryPath = ""
                pushedFile = nil
                pushedCommit = nil
            }
            isLoadingDetails = !store.isDemoMode
            await store.loadRepositoryTabIfNeeded(
                repoFullName: liveRepo.fullName,
                tab: store.selectedRepoTab,
                directoryPath: currentDirectoryPath
            )
            isLoadingDetails = false
        }
        .onChange(of: repository.id) { _, _ in
            currentDirectoryPath = ""
            pushedFile = nil
            pushedCommit = nil
        }
        .navigationDestination(item: $pushedPR) { pr in
            PullRequestWorkspaceView(pullRequest: pr)
        }
        .navigationDestination(item: $pushedFile) { file in
            RepoFileDetailView(repoFullName: liveRepo.fullName, file: file)
        }
        .navigationDestination(item: $pushedCommit) { commit in
            CommitDiffDetailView(repoFullName: liveRepo.fullName, commit: commit)
        }
        .onChange(of: store.routeNavigationID, initial: true) { _, requestID in
            guard requestID > 0, shouldPushInStack, store.selectedSection == .repos else { return }
            pushedPR = store.selectedPullRequest.flatMap {
                $0.repoFullName.caseInsensitiveCompare(liveRepo.fullName) == .orderedSame ? $0 : nil
            }
        }
        .sheet(isPresented: $showCloneSheet) {
            RepoCloneOverrideSheet(repoFullName: liveRepo.fullName)
                .preferredColorScheme(store.themePreference.colorScheme)
        }
        .sheet(isPresented: $showBranchSheet) {
            RepoBranchPickerSheet(
                branches: branches,
                activeBranch: store.activeBranch(for: liveRepo)
            ) { branch in
                currentDirectoryPath = ""
                pushedFile = nil
                Task { await store.selectRepositoryBranch(repoFullName: liveRepo.fullName, branch: branch) }
            }
            .preferredColorScheme(store.themePreference.colorScheme)
        }
    }

    private var stickySummaryHeader: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                HStack(alignment: .top, spacing: TeaPulseSpacing.sm) {
                    Text(liveRepo.fullName)
                        .font(TeaPulseTypography.headlineMd)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Spacer()
                    Button("克隆地址") {
                        showCloneSheet = true
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
                HStack(spacing: TeaPulseSpacing.sm) {
                    TeaPulseBranchTrigger(
                        branch: store.activeBranch(for: liveRepo),
                        hasBranches: !branches.isEmpty
                    ) {
                        showBranchSheet = true
                    }

                    if liveRepo.isMirror {
                        StatusBadge("镜像", tone: .tertiary)
                    }
                    Spacer()

                    Button {
                        Task { await store.toggleStarRepository(repoID: liveRepo.id) }
                    } label: {
                        Image(systemName: liveRepo.isStarred ? "star.fill" : "star")
                            .foregroundStyle(liveRepo.isStarred ? TeaPulseTheme.warning : TeaPulseTheme.secondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(TeaPulsePressableCardStyle())

                    Button {
                        store.togglePinRepository(liveRepo.fullName)
                    } label: {
                        Image(systemName: store.isRepositoryPinned(liveRepo.fullName) ? "pin.fill" : "pin")
                            .foregroundStyle(store.isRepositoryPinned(liveRepo.fullName) ? TeaPulseTheme.primary : TeaPulseTheme.secondary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(TeaPulsePressableCardStyle())
                }
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch store.selectedRepoTab {
        case .readme:
            readmeView
        case .files:
            filesView
        case .pullRequests:
            pullRequestsView
        case .issues:
            issuesKanbanView
        case .ops:
            RepoOpsSettingsView(repository: liveRepo)
        }
    }

    @ViewBuilder
    private var readmeView: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
            if !commits.isEmpty {
                RepoCommitsSectionView(commits: commits) { commit in
                    pushedCommit = commit
                }
            }
            if isRepoLoading && liveRepo.readmeMarkdown == "README 暂未加载" {
                LoadingStateCard("正在加载仓库概览…")
            } else {
                SurfaceCard {
                    MarkdownDocumentView(markdown: liveRepo.readmeMarkdown)
                }
            }
        }
    }

    private var filesView: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
            if !currentDirectoryPath.isEmpty {
                RepoFileBreadcrumbsView(path: currentDirectoryPath) { targetPath in
                    loadDirectory(targetPath)
                }
            }

            if files.isEmpty {
                if isRepoLoading {
                    LoadingStateCard("正在加载文件目录…")
                } else {
                    SurfaceCard {
                        Text("当前目录为空")
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                SurfaceCard {
                    VStack(spacing: TeaPulseSpacing.sm) {
                        ForEach(files) { file in
                            Button {
                                if file.isDirectory {
                                    if store.isDemoMode {
                                        store.showToast("演示模式暂不支持子目录钻取")
                                    } else {
                                        loadDirectory(file.path)
                                    }
                                } else {
                                    pushedFile = file
                                }
                            } label: {
                                HStack(spacing: TeaPulseSpacing.sm) {
                                    Image(systemName: file.isDirectory ? "folder" : "doc.text")
                                        .foregroundStyle(TeaPulseTheme.primary)
                                    Text(file.name.isEmpty ? file.path : file.name)
                                        .font(TeaPulseTypography.codeSm)
                                        .foregroundStyle(TeaPulseTheme.onSurface)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    if !file.isDirectory {
                                        Text(file.formattedSize)
                                            .font(TeaPulseTypography.codeSm)
                                            .monospacedDigit()
                                            .foregroundStyle(TeaPulseTheme.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(TeaPulseTypography.codeSm)
                                        .foregroundStyle(TeaPulseTheme.secondary)
                                }
                                .padding(.vertical, TeaPulseSpacing.xs)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(TeaPulsePressableCardStyle())
                        }
                    }
                }
            }
        }
    }

    private func loadDirectory(_ path: String) {
        currentDirectoryPath = path
        pushedFile = nil
        guard !store.isDemoMode else { return }
        Task {
            isLoadingDetails = true
            await store.loadRepositoryTabIfNeeded(
                repoFullName: liveRepo.fullName,
                tab: .files,
                directoryPath: path,
                force: true
            )
            isLoadingDetails = false
        }
    }

    private var pullRequestsView: some View {
        let stackedPRs = repoPRs
            .filter { $0.stackPosition != nil }
            .sorted { ($0.stackPosition ?? 0) > ($1.stackPosition ?? 0) }

        return VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
            Picker("合并请求视图", selection: Binding(
                get: { prDisplayMode },
                set: { next in TeaPulseMotion.run(TeaPulseMotion.snappy, reduceMotion: reduceMotion) { prDisplayMode = next } }
            )) {
                ForEach(PRDisplayMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 200)

            if prDisplayMode == .stacks && !stackedPRs.isEmpty {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
                        HStack(spacing: TeaPulseSpacing.sm) {
                            StatusBadge("合并列车 · \(stackedPRs.count) 层", tone: .tertiary)
                            Spacer()
                            if let basePR = stackedPRs.last {
                                Button("审阅 #\(basePR.number)") {
                                    store.selectedPRID = basePR.id
                                    if shouldPushInStack {
                                        pushedPR = basePR
                                    }
                                }
                                .buttonStyle(SecondaryActionButtonStyle())
                            }
                        }

                        ForEach(stackedPRs) { pr in
                            Button {
                                store.selectedPRID = pr.id
                                if shouldPushInStack {
                                    pushedPR = pr
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                                    HStack(alignment: .top, spacing: TeaPulseSpacing.sm) {
                                        StatusBadge("L\(pr.stackPosition ?? 1)", tone: .primary)
                                        Text("#\(pr.number) \(pr.title)")
                                            .font(TeaPulseTypography.bodySm)
                                            .foregroundStyle(TeaPulseTheme.onSurface)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                    }
                                    BranchRoutePill(pr.branchRouteLabel)
                                }
                                .padding(TeaPulseSpacing.sm)
                                .background(TeaPulseTheme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                            }
                            .buttonStyle(TeaPulsePressableCardStyle())
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: TeaPulseRadius.lg, style: .continuous)
                        .stroke(TeaPulseTheme.tertiary.opacity(0.45), lineWidth: 1)
                )
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            } else if repoPRs.isEmpty {
                if isRepoLoading {
                    LoadingStateCard("正在加载合并请求…")
                } else {
                    SurfaceCard {
                        Text("当前仓库暂无开放合并请求")
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else {
                ForEach(repoPRs) { pr in
                    Button {
                        store.selectedPRID = pr.id
                        if shouldPushInStack {
                            pushedPR = pr
                        }
                    } label: {
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                                HStack(spacing: TeaPulseSpacing.sm) {
                                    StatusBadge(pr.state == .merged ? "已合并" : "合并请求 #\(pr.number)", tone: pr.state == .merged ? .tertiary : .primary)
                                    if let pos = pr.stackPosition, let total = pr.stackTotal {
                                        StatusBadge("堆叠 \(pos)/\(total)", tone: .neutral)
                                    }
                                    Spacer()
                                    Text("+\(pr.additions) -\(pr.deletions)")
                                        .font(TeaPulseTypography.codeSm)
                                        .monospacedDigit()
                                        .foregroundStyle(TeaPulseTheme.primary)
                                }
                                Text(pr.title)
                                    .font(TeaPulseTypography.bodyMd)
                                    .foregroundStyle(TeaPulseTheme.onSurface)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                HStack {
                                    BranchRoutePill(pr.branchRouteLabel)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .buttonStyle(TeaPulsePressableCardStyle())
                }
            }
        }
        .animation(reduceMotion ? nil : TeaPulseMotion.snappy, value: prDisplayMode)
    }

    private var issuesKanbanView: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
            if issues.isEmpty && kanban.isEmpty {
                if isRepoLoading {
                    LoadingStateCard("正在加载议题…")
                } else {
                    SurfaceCard {
                        Text("当前仓库暂无开放议题")
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            ForEach(issues) { issue in
                SurfaceCard {
                    VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                        HStack(spacing: TeaPulseSpacing.sm) {
                            StatusBadge("#\(issue.number)", tone: .primary)
                            if !issue.blockedByNumbers.isEmpty {
                                StatusBadge("阻塞 #\(issue.blockedByNumbers[0])", tone: .warning)
                            }
                            Spacer()
                        }
                        Text(issue.title)
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if !kanban.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: TeaPulseSpacing.md) {
                        ForEach(["待处理", "进行中", "已完成"], id: \.self) { col in
                            SurfaceCard {
                                VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                                    Text(col)
                                        .font(TeaPulseTypography.labelMd)
                                        .foregroundStyle(TeaPulseTheme.secondary)
                                    ForEach(kanban.filter { $0.column == col }) { card in
                                        HStack {
                                            Text("#\(card.refNumber)")
                                                .font(TeaPulseTypography.codeSm)
                                                .foregroundStyle(TeaPulseTheme.primary)
                                            Text(card.title)
                                                .font(TeaPulseTypography.bodySm)
                                                .foregroundStyle(TeaPulseTheme.onSurface)
                                        }
                                    }
                                }
                                .frame(width: 210, alignment: .leading)
                            }
                        }
                    }
                }
            }
        }
    }
}
