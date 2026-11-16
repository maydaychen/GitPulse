import SwiftUI
import GiteaKit

public struct RunnersMonitorView: View {
    @Environment(AppStore.self) private var store
    @State private var isTokenSheetPresented = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.lg) {
                HStack(spacing: TeaPulseSpacing.sm) {
                    Text("执行节点池")
                        .font(TeaPulseTypography.headlineMd)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                    Spacer()
                    Button("+ 生成注册令牌") {
                        Task {
                            if await store.generateRunnerRegistrationToken() {
                                isTokenSheetPresented = true
                            }
                        }
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }

                if let token = store.lastRunnerRegistrationToken {
                    let registerCommand = """
                    act_runner register \\
                      --instance \(store.profile.publicURL) \\
                      --token \(token) \\
                      --name prod-runner-node \\
                      --labels ubuntu-latest,docker
                    """
                    SurfaceCard(elevated: true) {
                        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                            HStack(spacing: TeaPulseSpacing.sm) {
                                StatusBadge("POST /admin/runners/registration-token", tone: .tertiary)
                                Spacer()
                                Button("复制命令") {
                                    ClipboardService.copy(registerCommand)
                                    store.showToast("已复制注册命令")
                                }
                                .buttonStyle(SecondaryActionButtonStyle())
                            }
                            Text(registerCommand)
                                .font(TeaPulseTypography.codeSm)
                                .foregroundStyle(TeaPulseTheme.onSurface)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(TeaPulseSpacing.sm)
                                .background(TeaPulseTheme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous)
                                        .stroke(TeaPulseTheme.cardBorder, lineWidth: 1)
                                )
                        }
                    }
                }

                VStack(spacing: TeaPulseSpacing.md) {
                    if store.runners.isEmpty {
                        if store.isInitialWorkspaceLoading {
                            LoadingStateCard("正在加载执行节点…")
                        } else {
                            SurfaceCard {
                                Text("暂无在线或已注册的执行节点（查询节点池需管理员权限，或点击右上角生成注册令牌）")
                                    .font(TeaPulseTypography.bodySm)
                                    .foregroundStyle(TeaPulseTheme.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    ForEach(store.runners) { runner in
                        SurfaceCard {
                            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                                HStack(spacing: TeaPulseSpacing.sm) {
                                    PulsingStatusDot(
                                        color: dotColor(runner.status),
                                        animate: runner.status != .offline
                                    )
                                    Text(runner.name)
                                        .font(TeaPulseTypography.bodyMd)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(TeaPulseTheme.onSurface)
                                    Spacer()
                                    StatusBadge(runner.status.badgeLabel, tone: badgeTone(runner.status))
                                }

                                HStack(spacing: TeaPulseSpacing.sm) {
                                    StatusBadge(runner.hostLabel, tone: .neutral)
                                    if let active = runner.activeJobTitle {
                                        BranchRoutePill(active)
                                    }
                                    Spacer()
                                    Text("v\(runner.version)")
                                        .font(TeaPulseTypography.codeSm)
                                        .monospacedDigit()
                                        .foregroundStyle(TeaPulseTheme.secondary)
                                }

                                HStack(spacing: TeaPulseSpacing.xs) {
                                    ForEach(runner.labels.prefix(3), id: \.self) { label in
                                        BranchRoutePill(label)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(TeaPulseSpacing.md)
        }
        .background(TeaPulseTheme.surface)
        .sheet(isPresented: $isTokenSheetPresented) {
            runnerRegisterModal
                .preferredColorScheme(store.themePreference.colorScheme)
        }
    }

    private var runnerRegisterModal: some View {
        let token = store.lastRunnerRegistrationToken ?? "<REGISTRATION_TOKEN>"
        let registerCommand = """
        act_runner register \\
          --instance \(store.profile.publicURL) \\
          --token \(token) \\
          --name prod-runner-node \\
          --labels ubuntu-latest,docker
        """

        return NavigationStack {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
                SurfaceCard(elevated: true) {
                    VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                        HStack(spacing: TeaPulseSpacing.sm) {
                            StatusBadge("POST /admin/actions/runners/registration-token", tone: .tertiary)
                            Spacer()
                        }
                        Text(registerCommand)
                            .font(TeaPulseTypography.codeSm)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(TeaPulseSpacing.md)
                            .background(TeaPulseTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous)
                                    .stroke(TeaPulseTheme.cardBorder, lineWidth: 1)
                            )
                    }
                }

                Button("复制命令") {
                    ClipboardService.copy(registerCommand)
                    store.showToast("已复制注册命令")
                    isTokenSheetPresented = false
                }
                .buttonStyle(PrimaryActionButtonStyle(fullWidth: true))

                Spacer()
            }
            .padding(TeaPulseSpacing.md)
            .background(TeaPulseTheme.surface)
            .navigationTitle("节点注册命令")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { isTokenSheetPresented = false }
                }
            }
        }
    }

    private func dotColor(_ status: RunnerOnlineStatus) -> Color {
        switch status {
        case .online: return TeaPulseTheme.primary
        case .busy: return TeaPulseTheme.warning
        case .offline: return TeaPulseTheme.error
        }
    }

    private func badgeTone(_ status: RunnerOnlineStatus) -> StatusBadge.Tone {
        switch status {
        case .online: return .primary
        case .busy: return .warning
        case .offline: return .error
        }
    }
}
