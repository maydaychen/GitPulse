import SwiftUI
import GiteaKit

public struct RepoBranchPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let branches: [RepoBranchItem]
    public let activeBranch: String
    public let onSelect: (String) -> Void

    @State private var query = ""

    public init(branches: [RepoBranchItem], activeBranch: String, onSelect: @escaping (String) -> Void) {
        self.branches = branches
        self.activeBranch = activeBranch
        self.onSelect = onSelect
    }

    private var filtered: [RepoBranchItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return branches }
        return branches.filter { $0.name.lowercased().contains(trimmed) }
    }

    public var body: some View {
        TeaPulseModalSheet(
            title: "切换分支 / 标签",
            minWidth: 440,
            idealWidth: 480,
            minHeight: 380,
            idealHeight: 440,
            onClose: { dismiss() }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
                    TextField("搜索分支或标签…", text: $query)
                        .textFieldStyle(.plain)
                        .font(TeaPulseTypography.bodySm)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                        .padding(TeaPulseSpacing.sm)
                        .background(TeaPulseTheme.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous)
                                .stroke(TeaPulseTheme.cardBorder, lineWidth: 1)
                        )

                    if filtered.isEmpty {
                        SurfaceCard {
                            Text("未找到匹配的分支或标签")
                                .font(TeaPulseTypography.bodySm)
                                .foregroundStyle(TeaPulseTheme.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        SurfaceCard {
                            VStack(spacing: 0) {
                                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, item in
                                    if idx > 0 {
                                        Divider().overlay(TeaPulseTheme.cardBorder)
                                    }
                                    Button {
                                        onSelect(item.name)
                                        dismiss()
                                    } label: {
                                        HStack(spacing: TeaPulseSpacing.sm) {
                                            Image(systemName: item.isTag ? "tag" : "arrow.triangle.branch")
                                                .foregroundStyle(item.name == activeBranch ? TeaPulseTheme.primary : TeaPulseTheme.secondary)
                                            Text(item.name)
                                                .font(TeaPulseTypography.codeSm)
                                                .foregroundStyle(TeaPulseTheme.onSurface)
                                                .lineLimit(1)
                                            Spacer()
                                            if item.isDefault {
                                                StatusBadge("默认", tone: .neutral)
                                            }
                                            if item.name == activeBranch {
                                                Image(systemName: "checkmark")
                                                    .font(TeaPulseTypography.codeSm)
                                                    .foregroundStyle(TeaPulseTheme.primary)
                                            }
                                        }
                                        .padding(.vertical, TeaPulseSpacing.sm)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(TeaPulsePressableCardStyle())
                                }
                            }
                        }
                    }
                }
                .padding(TeaPulseSpacing.md)
            }
            .background(TeaPulseTheme.surface)
        }
    }
}

public struct RepoFileBreadcrumbsView: View {
    public let path: String
    public let onSelectPath: (String) -> Void

    public init(path: String, onSelectPath: @escaping (String) -> Void) {
        self.path = path
        self.onSelectPath = onSelectPath
    }

    private var segments: [(label: String, targetPath: String)] {
        let parts = path.split(separator: "/").map(String.init)
        var cumulative = ""
        return parts.map { part in
            cumulative = cumulative.isEmpty ? part : "\(cumulative)/\(part)"
            return (part, cumulative)
        }
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: TeaPulseSpacing.xs) {
                Button("根目录") {
                    onSelectPath("")
                }
                .buttonStyle(SecondaryActionButtonStyle())

                ForEach(segments, id: \.targetPath) { seg in
                    Image(systemName: "chevron.right")
                        .font(TeaPulseTypography.codeSm)
                        .foregroundStyle(TeaPulseTheme.secondary)
                    Button(seg.label) {
                        onSelectPath(seg.targetPath)
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }
}

public struct RepoCommitsSectionView: View {
    public let commits: [RepoCommitItem]
    public let onSelect: (RepoCommitItem) -> Void

    @State private var isExpanded = false

    public init(commits: [RepoCommitItem], onSelect: @escaping (RepoCommitItem) -> Void) {
        self.commits = commits
        self.onSelect = onSelect
    }

    private var visibleCommits: [RepoCommitItem] {
        isExpanded ? commits : Array(commits.prefix(4))
    }

    public var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                HStack(spacing: TeaPulseSpacing.sm) {
                    Text("最近提交")
                        .font(TeaPulseTypography.headlineMd)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                    Spacer()
                    StatusBadge("\(commits.count)", tone: .neutral)
                    if commits.count > 4 {
                        Button(isExpanded ? "收起" : "全部 \(commits.count)") {
                            isExpanded.toggle()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }

                VStack(spacing: 0) {
                    ForEach(Array(visibleCommits.enumerated()), id: \.element.id) { idx, commit in
                        if idx > 0 {
                            Divider().overlay(TeaPulseTheme.cardBorder)
                        }
                        Button {
                            onSelect(commit)
                        } label: {
                            VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                                HStack(spacing: TeaPulseSpacing.sm) {
                                    BranchRoutePill(commit.shortSHA)
                                    Text(commit.author)
                                        .font(TeaPulseTypography.codeSm)
                                        .foregroundStyle(TeaPulseTheme.primary)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(commit.timestampText)
                                        .font(TeaPulseTypography.codeSm)
                                        .monospacedDigit()
                                        .foregroundStyle(TeaPulseTheme.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(TeaPulseTypography.codeSm)
                                        .foregroundStyle(TeaPulseTheme.secondary)
                                }
                                Text(commit.title)
                                    .font(TeaPulseTypography.bodySm)
                                    .foregroundStyle(TeaPulseTheme.onSurface)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
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

public struct CommitDiffDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    public let repoFullName: String
    public let commit: RepoCommitItem

    @State private var patches: [DiffFilePatch] = []
    @State private var isLoading = false

    public init(repoFullName: String, commit: RepoCommitItem) {
        self.repoFullName = repoFullName
        self.commit = commit
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.lg) {
                #if os(macOS)
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Label("返回 \(repoFullName)", systemImage: "chevron.left")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    Spacer()
                }
                #endif

                SurfaceCard {
                    VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                        HStack(spacing: TeaPulseSpacing.sm) {
                            BranchRoutePill(commit.shortSHA)
                            Spacer()
                            Text(commit.timestampText)
                                .font(TeaPulseTypography.codeSm)
                                .monospacedDigit()
                                .foregroundStyle(TeaPulseTheme.secondary)
                        }
                        Text(commit.message.isEmpty ? commit.title : commit.message)
                            .font(TeaPulseTypography.bodyMd)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("@\(commit.author)")
                            .font(TeaPulseTypography.codeSm)
                            .foregroundStyle(TeaPulseTheme.primary)
                    }
                }

                DiffReaderView(
                    prID: "commit-\(commit.sha)",
                    files: patches,
                    comments: [],
                    isLoading: isLoading,
                    allowsCommenting: false
                )
            }
            .padding(TeaPulseSpacing.md)
        }
        .background(TeaPulseTheme.surface)
        .navigationTitle(commit.shortSHA)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task(id: commit.sha) {
            isLoading = true
            patches = await store.loadCommitDiff(repoFullName: repoFullName, sha: commit.sha)
            isLoading = false
        }
        .refreshable {
            isLoading = true
            patches = await store.loadCommitDiff(repoFullName: repoFullName, sha: commit.sha)
            isLoading = false
        }
    }
}

public struct RepoCloneOverrideSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    public let repoFullName: String

    public init(repoFullName: String) {
        self.repoFullName = repoFullName
    }

    public var body: some View {
        let host = URL(string: store.profile.publicURL)?.host ?? "git.example.com"
        let httpsOverride = GiteaURLBuilder.overriddenCloneHTTPS(repoFullName: repoFullName, proxyBaseURL: store.profile.publicURL)
        let sshOverride = GiteaURLBuilder.overriddenCloneSSH(repoFullName: repoFullName, host: host, sshPort: store.profile.sshPortOverride)

        TeaPulseModalSheet(
            title: "克隆地址",
            minWidth: 480,
            idealWidth: 520,
            minHeight: 260,
            idealHeight: 290,
            onClose: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
                cloneCopyCard(title: "反代 HTTPS", url: httpsOverride)
                cloneCopyCard(title: "独立 SSH 端口", url: sshOverride)
                Spacer()
            }
            .padding(TeaPulseSpacing.md)
            .background(TeaPulseTheme.surface)
        }
    }

    private func cloneCopyCard(title: String, url: String) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                HStack {
                    Text(title)
                        .font(TeaPulseTypography.labelMd)
                        .foregroundStyle(TeaPulseTheme.secondary)
                    Spacer()
                    Button("复制") {
                        ClipboardService.copy(url)
                        store.showToast("已复制 \(title)")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
                Text(url)
                    .font(TeaPulseTypography.codeSm)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                    .textSelection(.enabled)
            }
        }
    }
}
