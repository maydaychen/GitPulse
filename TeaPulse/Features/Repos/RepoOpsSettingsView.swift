import SwiftUI
import GiteaKit

public struct RepoOpsSettingsView: View {
    @Environment(AppStore.self) private var store
    public let repository: RepositorySummary

    @State private var newSecretName = ""
    @State private var newSecretValue = ""
    @State private var newVarName = ""
    @State private var newVarValue = ""

    public init(repository: RepositorySummary) {
        self.repository = repository
    }

    private func lookup<T>(_ dict: [String: [T]]) -> [T] {
        dict[store.canonicalRepoName(repository.fullName)]
            ?? dict.first { $0.key.caseInsensitiveCompare(repository.fullName) == .orderedSame }?.value
            ?? []
    }

    private var secrets: [RepoSecretItem] { lookup(store.secretsByRepo) }
    private var variables: [RepoVariableItem] { lookup(store.variablesByRepo) }
    private var webhooks: [WebhookConfig] { lookup(store.webhooksByRepo) }
    private var releases: [ReleaseItem] { lookup(store.releasesByRepo) }
    private var isLoading: Bool { store.isLoadingRepoDetails(repository.fullName) }

    public var body: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.lg) {
            if repository.isMirror {
                mirrorCard
            }
            secretsSection
            variablesSection
            webhooksSection
            releasesSection
        }
    }

    private var mirrorCard: some View {
        SurfaceCard {
            HStack(spacing: TeaPulseSpacing.sm) {
                VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                    Text("镜像同步状态")
                        .font(TeaPulseTypography.headlineMd)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                    Text("周期 \(repository.mirrorInterval ?? "4h") · 上次 \(repository.lastMirrorSyncText ?? "-")")
                        .font(TeaPulseTypography.codeSm)
                        .foregroundStyle(TeaPulseTheme.secondary)
                }
                Spacer()
                Button("立即同步") {
                    Task { await store.triggerMirrorSync(repoID: repository.id) }
                }
                .buttonStyle(PrimaryActionButtonStyle())
            }
        }
    }

    private var secretsSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                HStack {
                    Text("工作流密钥")
                        .font(TeaPulseTypography.headlineMd)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                    Spacer()
                    StatusBadge("\(secrets.count)", tone: .neutral)
                }

                if secrets.isEmpty {
                    loadingOrEmpty("暂无已配置的工作流密钥")
                }

                ForEach(secrets) { sec in
                    HStack(spacing: TeaPulseSpacing.sm) {
                        Text(sec.name)
                            .font(TeaPulseTypography.codeSm)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                            .lineLimit(2)
                        Spacer()
                        Text(sec.updatedAtText)
                            .font(TeaPulseTypography.codeSm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                        Button {
                            Task {
                                await store.deleteSecret(repoFullName: repository.fullName, id: sec.id)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(TeaPulseTheme.error)
                                .padding(TeaPulseSpacing.sm)
                                .frame(minWidth: 36, minHeight: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(TeaPulsePressableCardStyle())
                    }
                }

                VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                    inputChrome(TextField("密钥名称（如 DEPLOY_KEY）", text: $newSecretName))
                    inputChrome(SecureField("密钥内容", text: $newSecretValue))
                    HStack {
                        Spacer()
                        Button("写入") {
                            Task {
                                if await store.upsertSecret(repoFullName: repository.fullName, name: newSecretName, value: newSecretValue) {
                                    newSecretName = ""
                                    newSecretValue = ""
                                }
                            }
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }
        }
    }

    private var variablesSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                HStack {
                    Text("工作流变量")
                        .font(TeaPulseTypography.headlineMd)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                    Spacer()
                    StatusBadge("\(variables.count)", tone: .neutral)
                }

                if variables.isEmpty {
                    loadingOrEmpty("暂无已配置的工作流变量")
                }

                ForEach(variables) { item in
                    HStack(spacing: TeaPulseSpacing.sm) {
                        VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                            Text(item.name)
                                .font(TeaPulseTypography.codeSm)
                                .foregroundStyle(TeaPulseTheme.primary)
                            Text(item.value)
                                .font(TeaPulseTypography.codeSm)
                                .foregroundStyle(TeaPulseTheme.onSurface)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button {
                            Task {
                                await store.deleteVariable(repoFullName: repository.fullName, id: item.id)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(TeaPulseTheme.error)
                                .padding(TeaPulseSpacing.sm)
                                .frame(minWidth: 36, minHeight: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(TeaPulsePressableCardStyle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                    inputChrome(TextField("变量名称（如 BUILD_ENV）", text: $newVarName))
                    inputChrome(TextField("变量内容", text: $newVarValue))
                    HStack {
                        Spacer()
                        Button("保存") {
                            Task {
                                if await store.upsertVariable(repoFullName: repository.fullName, name: newVarName, value: newVarValue) {
                                    newVarName = ""
                                    newVarValue = ""
                                }
                            }
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }
            }
        }
    }

    private var webhooksSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                Text("网络钩子投递与重放")
                    .font(TeaPulseTypography.headlineMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)

                if webhooks.isEmpty {
                    loadingOrEmpty("当前仓库未配置 Webhook（需要仓库管理权限）")
                }

                ForEach(webhooks) { hook in
                    let statusLabel = hook.lastStatusCode > 0 ? "HTTP \(hook.lastStatusCode)" : (hook.isActive ? "已启用" : "已停用")
                    let statusTone: StatusBadge.Tone = hook.lastStatusCode >= 400 ? .error : (hook.lastStatusCode > 0 || hook.isActive ? .primary : .neutral)
                    VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                        HStack(spacing: TeaPulseSpacing.sm) {
                            StatusBadge(statusLabel, tone: statusTone)
                            if let firstEvent = hook.events.first {
                                StatusBadge(firstEvent, tone: .neutral)
                            }
                            Spacer()
                            Button("重放") {
                                Task { await store.replayWebhook(repoFullName: repository.fullName, hookID: hook.id) }
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                        Text(hook.targetURL)
                            .font(TeaPulseTypography.codeSm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                        ForEach(hook.deliveries) { delivery in
                            HStack(spacing: TeaPulseSpacing.sm) {
                                Text("\(delivery.statusCode)")
                                    .font(TeaPulseTypography.codeSm)
                                    .monospacedDigit()
                                    .foregroundStyle(delivery.statusCode >= 400 ? TeaPulseTheme.error : TeaPulseTheme.primary)
                                Text(delivery.eventName)
                                    .font(TeaPulseTypography.codeSm)
                                    .foregroundStyle(TeaPulseTheme.onSurface)
                                Spacer()
                                Text(delivery.deliveredAtText)
                                    .font(TeaPulseTypography.codeSm)
                                    .monospacedDigit()
                                    .foregroundStyle(TeaPulseTheme.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var releasesSection: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                Text("发行版本")
                    .font(TeaPulseTypography.headlineMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                if releases.isEmpty {
                    loadingOrEmpty("当前仓库暂无发行版本")
                }
                ForEach(releases) { rel in
                    VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                        HStack(spacing: TeaPulseSpacing.sm) {
                            StatusBadge(rel.tagName, tone: .primary)
                            Spacer()
                            Text(rel.publishedAtText)
                                .font(TeaPulseTypography.codeSm)
                                .foregroundStyle(TeaPulseTheme.secondary)
                        }
                        Text(rel.title)
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func loadingOrEmpty(_ emptyText: String) -> some View {
        if isLoading {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                HStack(spacing: TeaPulseSpacing.sm) {
                    ProgressView()
                        .tint(TeaPulseTheme.primary)
                    Text("正在加载…")
                        .font(TeaPulseTypography.bodySm)
                        .foregroundStyle(TeaPulseTheme.secondary)
                }
                LoadingSkeletonRows()
            }
        } else {
            Text(emptyText)
                .font(TeaPulseTypography.bodySm)
                .foregroundStyle(TeaPulseTheme.secondary)
        }
    }

    private func inputChrome<Field: View>(_ field: Field) -> some View {
        field
            .textFieldStyle(.plain)
            .font(TeaPulseTypography.codeSm)
            .foregroundStyle(TeaPulseTheme.onSurface)
            .padding(TeaPulseSpacing.sm)
            .background(TeaPulseTheme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
    }
}
