import SwiftUI
import GiteaKit

public struct OpsWorkspaceView: View {
    @Environment(AppStore.self) private var store
    @State private var confirmCron: CronTaskItem?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.lg) {
                headerRow
                statsGrid
                cronSection
                usersSection
                packagesSection
            }
            .padding(TeaPulseSpacing.md)
        }
        .background(TeaPulseTheme.surface)
        .refreshable {
            await store.refreshLiveInstanceData()
        }
        .confirmationDialog(
            "确认触发系统任务？",
            isPresented: Binding(
                get: { confirmCron != nil },
                set: { if !$0 { confirmCron = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let task = confirmCron {
                Button("立即执行 \(task.name)", role: .destructive) {
                    Task { await store.triggerCronTask(task.id) }
                    confirmCron = nil
                }
            }
            Button("取消", role: .cancel) { confirmCron = nil }
        }
    }

    private var headerRow: some View {
        HStack(spacing: TeaPulseSpacing.sm) {
            Text("运维")
                .font(TeaPulseTypography.headlineLg)
                .foregroundStyle(TeaPulseTheme.onSurface)
                .lineLimit(1)
            Spacer()
            EndpointProbePill(health: store.health) {
                store.isConnectionSheetPresented = true
            }
        }
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: TeaPulseSpacing.md),
                GridItem(.flexible(), spacing: TeaPulseSpacing.md)
            ],
            spacing: TeaPulseSpacing.md
        ) {
            statCard(title: "实例版本", value: store.adminStats.serverVersion, tone: .primary)
            statCard(title: "在线节点", value: "\(store.adminStats.activeRunners)/\(store.adminStats.activeRunners + store.adminStats.offlineRunners)", tone: store.adminStats.offlineRunners > 0 ? .warning : .primary)
            statCard(title: "托管仓库", value: "\(store.adminStats.totalRepos)", tone: .neutral)
            statCard(title: "制品包", value: "\(store.adminStats.packageCount)", tone: .neutral)
        }
    }

    private func statCard(title: String, value: String, tone: StatusBadge.Tone) -> some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                Text(title)
                    .font(TeaPulseTypography.labelMd)
                    .foregroundStyle(TeaPulseTheme.secondary)
                Text(value)
                    .font(TeaPulseTypography.headlineMd)
                    .monospacedDigit()
                    .foregroundStyle(tone == .warning ? TeaPulseTheme.warning : (tone == .primary ? TeaPulseTheme.primary : TeaPulseTheme.onSurface))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var cronSection: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
            Text("系统定时任务")
                .font(TeaPulseTypography.labelMd)
                .foregroundStyle(TeaPulseTheme.secondary)

            VStack(spacing: TeaPulseSpacing.md) {
                if store.cronTasks.isEmpty {
                    if store.isInitialWorkspaceLoading {
                        LoadingStateCard("正在加载定时任务…")
                    } else {
                        SurfaceCard {
                            Text("暂无系统定时任务（需管理员权限）")
                                .font(TeaPulseTypography.bodySm)
                                .foregroundStyle(TeaPulseTheme.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                ForEach(store.cronTasks) { task in
                    SurfaceCard {
                        HStack(alignment: .top, spacing: TeaPulseSpacing.sm) {
                            VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                                Text(task.name)
                                    .font(TeaPulseTypography.codeSm)
                                    .foregroundStyle(TeaPulseTheme.onSurface)
                                    .lineLimit(2)
                                Text("\(task.schedule) · 已运行 \(task.execTimes) 次 · 上次 \(task.lastRunText)")
                                    .font(TeaPulseTypography.labelMd)
                                    .monospacedDigit()
                                    .foregroundStyle(TeaPulseTheme.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Button("触发") {
                                if task.isDestructive {
                                    confirmCron = task
                                } else {
                                    Task { await store.triggerCronTask(task.id) }
                                }
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private var usersSection: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
            Text("用户治理")
                .font(TeaPulseTypography.labelMd)
                .foregroundStyle(TeaPulseTheme.secondary)

            VStack(spacing: TeaPulseSpacing.sm) {
                if store.adminUsers.isEmpty {
                    if store.isInitialWorkspaceLoading {
                        LoadingStateCard("正在加载用户治理数据…")
                    } else {
                        SurfaceCard {
                            Text("暂无用户治理数据（需管理员权限）")
                                .font(TeaPulseTypography.bodySm)
                                .foregroundStyle(TeaPulseTheme.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                ForEach(store.adminUsers) { user in
                    SurfaceCard {
                        HStack(alignment: .top, spacing: TeaPulseSpacing.sm) {
                            VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                                HStack(spacing: TeaPulseSpacing.sm) {
                                    Text(user.login)
                                        .font(TeaPulseTypography.codeSm)
                                        .foregroundStyle(TeaPulseTheme.onSurface)
                                    if user.isAdmin {
                                        StatusBadge("管理员", tone: .tertiary)
                                    }
                                    if user.prohibitLogin {
                                        StatusBadge("禁登", tone: .error)
                                    }
                                }
                                Text("\(user.email) · \(user.repoCount) 仓库")
                                    .font(TeaPulseTypography.labelMd)
                                    .foregroundStyle(TeaPulseTheme.secondary)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button(user.prohibitLogin ? "解禁" : "禁登") {
                                store.toggleUserProhibitLogin(user.id)
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                }
            }
        }
    }

    private var packagesSection: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
            Text("制品包清理")
                .font(TeaPulseTypography.labelMd)
                .foregroundStyle(TeaPulseTheme.secondary)

            VStack(spacing: TeaPulseSpacing.sm) {
                if store.packages.isEmpty {
                    if store.isInitialWorkspaceLoading {
                        LoadingStateCard("正在加载制品包记录…")
                    } else {
                        SurfaceCard {
                            Text("暂无制品包记录")
                                .font(TeaPulseTypography.bodySm)
                                .foregroundStyle(TeaPulseTheme.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                ForEach(store.packages) { pkg in
                    SurfaceCard {
                        HStack(alignment: .top, spacing: TeaPulseSpacing.sm) {
                            StatusBadge(pkg.type, tone: .neutral)
                            VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                                Text("\(pkg.owner)/\(pkg.name)")
                                    .font(TeaPulseTypography.codeSm)
                                    .foregroundStyle(TeaPulseTheme.onSurface)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                Text("\(pkg.version) · \(pkg.sizeLabel)")
                                    .font(TeaPulseTypography.labelMd)
                                    .foregroundStyle(TeaPulseTheme.secondary)
                            }
                            Spacer()
                            Button("删除") {
                                store.deletePackage(pkg.id)
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                    }
                }
            }
        }
    }
}
