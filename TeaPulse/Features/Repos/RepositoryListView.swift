import SwiftUI
import GiteaKit

public struct RepositoryListView: View {
    @Environment(AppStore.self) private var store
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @State private var pushedRepo: RepositorySummary?

    private var shouldPushInStack: Bool {
        #if os(iOS)
        return sizeClass == .compact
        #else
        return false
        #endif
    }

    public init() {}

    public var body: some View {
        @Bindable var bindableStore = store

        ScrollView {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.lg) {
                headerRow

                TextField("搜索仓库名称或所属组织…", text: $bindableStore.repoSearchQuery)
                    .textFieldStyle(.plain)
                    .font(TeaPulseTypography.bodySm)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .padding(TeaPulseSpacing.sm)
                    .background(TeaPulseTheme.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))

                VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: TeaPulseSpacing.sm) {
                            ForEach(RepoScope.allCases, id: \.self) { scope in
                                FilterChipButton(
                                    title: scope.rawValue,
                                    isSelected: store.repoScopeFilter == scope
                                ) {
                                    store.selectRepoScope(scope)
                                }
                            }
                        }
                    }

                    if !store.availableOrganizations.isEmpty && store.repoScopeFilter != .personal {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: TeaPulseSpacing.sm) {
                                FilterChipButton(
                                    title: (store.repoScopeFilter == .all || store.repoScopeFilter == .org) ? "全部组织" : "不限组织",
                                    count: (store.repoScopeFilter == .all || store.repoScopeFilter == .org) ? store.allOrganizationsRepoCount : nil,
                                    isSelected: store.repoScopeFilter != .all && store.selectedOrganizationFilter == nil
                                ) {
                                    store.clearOrganizationFilter()
                                }

                                ForEach(store.availableOrganizations) { org in
                                    FilterChipButton(
                                        title: org.username,
                                        count: store.repositoryCount(forOrganization: org.username),
                                        isSelected: store.isOrganizationSelected(org.username)
                                    ) {
                                        store.toggleOrganizationFilter(org.username)
                                    }
                                }
                            }
                        }
                    }
                }

                LazyVStack(spacing: TeaPulseSpacing.md) {
                    if store.filteredRepositories.isEmpty {
                        if store.isInitialWorkspaceLoading || store.isResolvingRoute {
                            LoadingStateCard("正在加载仓库列表…")
                        } else {
                            SurfaceCard {
                                Text(emptyStateMessage)
                                    .font(TeaPulseTypography.bodySm)
                                    .foregroundStyle(TeaPulseTheme.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } else {
                        ForEach(store.filteredRepositories) { repo in
                            SurfaceCard(isSelected: !shouldPushInStack && store.selectedRepoID == repo.id) {
                                VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                                    Button {
                                        store.selectedRepoID = repo.id
                                        store.selectedPRID = nil
                                        if shouldPushInStack {
                                            pushedRepo = repo
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                                            Text(repo.fullName)
                                                .font(TeaPulseTypography.bodyMd)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(TeaPulseTheme.onSurface)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            HStack(spacing: TeaPulseSpacing.xs) {
                                                BranchRoutePill(repo.defaultBranch)
                                                if repo.isMirror {
                                                    StatusBadge(repo.lastMirrorSyncText ?? "镜像", tone: .tertiary)
                                                }
                                                if repo.openPRCount > 0 {
                                                    StatusBadge("\(repo.openPRCount) 合并请求", tone: .primary)
                                                }
                                                Spacer()
                                            }

                                            HStack(spacing: TeaPulseSpacing.sm) {
                                                if !repo.isMirror || repo.isStarred {
                                                    Label("\(repo.stars)", systemImage: repo.isStarred ? "star.fill" : "star")
                                                        .font(TeaPulseTypography.codeSm)
                                                        .monospacedDigit()
                                                        .foregroundStyle(repo.isStarred ? TeaPulseTheme.warning : TeaPulseTheme.secondary)
                                                }
                                                Spacer()
                                                if !repo.updatedAtText.isEmpty {
                                                    Text(repo.updatedAtText)
                                                        .font(TeaPulseTypography.codeSm)
                                                        .monospacedDigit()
                                                        .foregroundStyle(TeaPulseTheme.secondary)
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(TeaPulsePressableCardStyle())

                                    if repo.isMirror {
                                        HStack {
                                            Spacer()
                                            Button("同步") {
                                                Task { await store.triggerMirrorSync(repoID: repo.id) }
                                            }
                                            .buttonStyle(SecondaryActionButtonStyle())
                                        }
                                    }
                                }
                            }
                            .contextMenu {
                                Button(store.isRepositoryPinned(repo.fullName) ? "取消置顶" : "置顶到首页") {
                                    store.togglePinRepository(repo.fullName)
                                }
                                Button(repo.isStarred ? "取消收藏" : "收藏仓库") {
                                    Task { await store.toggleStarRepository(repoID: repo.id) }
                                }
                            }
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
        .navigationDestination(item: $pushedRepo) { repo in
            RepositoryWorkspaceView(repository: repo)
        }
        .onChange(of: store.routeNavigationID, initial: true) { _, requestID in
            guard requestID > 0, shouldPushInStack, store.selectedSection == .repos else { return }
            pushedRepo = store.selectedRepository
        }
    }

    private var emptyStateMessage: String {
        if let org = store.selectedOrganizationFilter?.trimmingCharacters(in: .whitespacesAndNewlines),
           !org.isEmpty {
            return "组织 \(org) 下未找到匹配的仓库"
        }
        return "未找到匹配的仓库"
    }

    private var headerRow: some View {
        HStack(spacing: TeaPulseSpacing.sm) {
            Text("仓库")
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
}
