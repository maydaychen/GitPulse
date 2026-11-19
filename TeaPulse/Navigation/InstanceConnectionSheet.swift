import SwiftUI
import GiteaKit

public struct InstanceConnectionSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var isProbing = false

    public init() {}

    private var activeChannel: EndpointChannel {
        store.health.channel == .demo ? store.profile.activeChannel : store.health.channel
    }

    public var body: some View {
        @Bindable var bindableStore = store

        TeaPulseModalSheet(
            title: "实例通道与外观",
            minWidth: 500,
            idealWidth: 540,
            minHeight: 440,
            idealHeight: 500,
            onClose: { dismiss() }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: TeaPulseSpacing.lg) {
                    SurfaceCard {
                        VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
                            HStack(spacing: TeaPulseSpacing.sm) {
                                Text("切换连接通道")
                                    .font(TeaPulseTypography.headlineMd)
                                    .foregroundStyle(TeaPulseTheme.onSurface)
                                Spacer()
                                Button(isProbing ? "探测中…" : "重新探测") {
                                    Task {
                                        isProbing = true
                                        await store.refreshEndpointProbe()
                                        isProbing = false
                                    }
                                }
                                .buttonStyle(SecondaryActionButtonStyle())
                                .disabled(isProbing)
                            }

                            channelOptionCard(
                                channel: .publicProxy,
                                title: "Nginx HTTPS (公网反代)",
                                urlString: store.profile.publicURL,
                                latencyMs: store.proxyLatencyMs
                            )

                            if let lanURL = store.profile.lanURL, !lanURL.isEmpty {
                                channelOptionCard(
                                    channel: .lanDirect,
                                    title: "LAN 直连 (800ms 竞速)",
                                    urlString: lanURL,
                                    latencyMs: store.lanLatencyMs
                                )
                            }
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                            Text("界面外观")
                                .font(TeaPulseTypography.labelMd)
                                .foregroundStyle(TeaPulseTheme.secondary)

                            TeaPulseThemeSwitcher(selection: $bindableStore.themePreference)
                        }
                    }

                    SurfaceCard {
                        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                            HStack(spacing: TeaPulseSpacing.sm) {
                                VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                                    Text(store.isDemoMode ? "当前处于演示沙盒" : "实例凭据与网关设置")
                                        .font(TeaPulseTypography.bodyMd)
                                        .foregroundStyle(TeaPulseTheme.onSurface)
                                    Text("\(store.profile.username.isEmpty ? "未登录" : "@\(store.profile.username)") · Gitea \(store.health.serverVersion)")
                                        .font(TeaPulseTypography.codeSm)
                                        .foregroundStyle(TeaPulseTheme.secondary)
                                }
                                Spacer()
                                Button("登录门面") {
                                    dismiss()
                                    store.isLoginGatePresented = true
                                }
                                .buttonStyle(PrimaryActionButtonStyle())
                            }
                        }
                    }

                    HStack(spacing: TeaPulseSpacing.md) {
                        Button(store.isDemoMode ? "恢复初始演示数据" : "重置为演示模式") {
                            store.switchToDemoMode()
                            dismiss()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())

                        Spacer()
                    }
                }
                .padding(TeaPulseSpacing.md)
            }
            .background(TeaPulseTheme.surface)
        }
    }

    private func channelOptionCard(
        channel: EndpointChannel,
        title: String,
        urlString: String,
        latencyMs: Int
    ) -> some View {
        let isActive = activeChannel == channel
        return Button {
            Task {
                await store.selectEndpointChannel(channel)
            }
        } label: {
            HStack(spacing: TeaPulseSpacing.sm) {
                PulsingStatusDot(
                    color: isActive ? TeaPulseTheme.primary : TeaPulseTheme.secondary,
                    animate: isActive
                )
                VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                    Text(title)
                        .font(TeaPulseTypography.bodySm)
                        .fontWeight(.semibold)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                    Text(urlString)
                        .font(TeaPulseTypography.codeSm)
                        .foregroundStyle(TeaPulseTheme.secondary)
                        .lineLimit(1)
                }
                Spacer()
                StatusBadge("\(latencyMs)ms", tone: isActive ? .primary : .neutral)
            }
            .padding(TeaPulseSpacing.sm)
            .background(isActive ? TeaPulseTheme.surfaceElevated : TeaPulseTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous)
                    .stroke(isActive ? TeaPulseTheme.primary : TeaPulseTheme.cardBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(TeaPulsePressableCardStyle())
    }
}
