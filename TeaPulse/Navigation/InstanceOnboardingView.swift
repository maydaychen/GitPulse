import SwiftUI
import GiteaKit

public struct InstanceOnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var displayName = "Gitea 主实例"
    @State private var publicURL = ""
    @State private var lanURL = ""
    @State private var preferredChannel: EndpointChannel = .publicProxy
    @State private var patToken = ""
    @State private var revealToken = false
    @State private var sshPortText = "2222"
    @State private var barkURL = ""
    @State private var customHeaderKey = ""
    @State private var customHeaderValue = ""
    @State private var showGatewayOptions = false
    @State private var isProbing = false
    @State private var isConnecting = false
    @State private var connectionTask: Task<Void, Never>?
    @State private var connectionError: String?
    @State private var diagnostics: [LoginDiagnosticStep] = [
        LoginDiagnosticStep(id: "s1", title: "URL 与反代端口解析", detail: "支持独立反代端口与子路径", state: .pending),
        LoginDiagnosticStep(id: "s2", title: "/api/healthz 实例探针", detail: "LAN 800ms 竞速 · TLS 降级", state: .pending),
        LoginDiagnosticStep(id: "s3", title: "PAT 身份验证", detail: "写入设备 Keychain 隔离", state: .pending)
    ]

    public init() {}

    public var body: some View {
        @Bindable var bindableStore = store

        ScrollView {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.lg) {
                heroHeader(theme: $bindableStore.themePreference)
                    .teaPulseStaggeredReveal(index: 0)
                dualLinkCard
                    .teaPulseStaggeredReveal(index: 1)
                authVaultCard
                    .teaPulseStaggeredReveal(index: 2)
                handshakePipelineCard
                    .teaPulseStaggeredReveal(index: 3)
                gatewayDisclosureCard
                    .teaPulseStaggeredReveal(index: 4)
                actionDock
                    .teaPulseStaggeredReveal(index: 5)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(TeaPulseSpacing.md)
        }
        .background(TeaPulseTheme.surface.ignoresSafeArea())
        .onAppear {
            if publicURL.isEmpty {
                displayName = store.profile.displayName
                publicURL = store.isDemoMode ? InstanceProfile.placeholderPublicURL : store.profile.publicURL
                lanURL = store.isDemoMode ? InstanceProfile.placeholderLANURL : (store.profile.lanURL ?? "")
                preferredChannel = store.profile.activeChannel == .demo ? .publicProxy : store.profile.activeChannel
                sshPortText = store.profile.sshPortOverride.map(String.init) ?? "2222"
                barkURL = store.isDemoMode ? "" : (store.profile.barkEndpointURL ?? "")
                if !store.isDemoMode,
                   let creds = store.credentialStore.loadCredentials(forProfileID: store.profile.id) {
                    patToken = creds.patToken
                    if let firstHeader = creds.customHeaders.sorted(by: { $0.key < $1.key }).first {
                        customHeaderKey = firstHeader.key
                        customHeaderValue = firstHeader.value
                        showGatewayOptions = true
                    }
                }
            }
        }
        .onDisappear {
            if store.connectionAttemptID != nil { connectionTask?.cancel() }
        }
    }

    private func heroHeader(theme: Binding<ThemePreference>) -> some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
            HStack(spacing: TeaPulseSpacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: TeaPulseRadius.lg, style: .continuous)
                        .fill(TeaPulseTheme.surfaceElevated)
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: TeaPulseRadius.lg, style: .continuous)
                                .stroke(TeaPulseTheme.primary.opacity(0.35), lineWidth: 1)
                        )
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(TeaPulseTheme.primary)
                        .symbolEffect(.pulse, isActive: (isProbing || isConnecting) && !reduceMotion)
                }

                VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                    Text("TeaPulse")
                        .font(TeaPulseTypography.headlineLg)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                    HStack(spacing: TeaPulseSpacing.xs) {
                        PulsingStatusDot(color: TeaPulseTheme.primary, animate: true)
                        Text("自托管 Gitea 双通道工作台")
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                TeaPulseDropdownMenu(
                    items: ThemePreference.allCases.map { option in
                        TeaPulseDropdownItem(
                            value: option,
                            title: option.rawValue,
                            icon: option.iconName,
                            accessibilityID: "themeOption-\(option.rawValue)"
                        )
                    },
                    selection: theme,
                    triggerAccessibilityID: "loginThemeMenu",
                    preferredColorScheme: theme.wrappedValue.colorScheme
                )
            }
        }
    }

    private var dualLinkCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
                Text("连接地址")
                    .font(TeaPulseTypography.headlineMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)

                HStack(spacing: TeaPulseSpacing.sm) {
                    channelSelectorCard(channel: .publicProxy, title: "公网反代", subtitle: "Nginx TLS", latencyText: "\(store.proxyLatencyMs)ms")
                    channelSelectorCard(channel: .lanDirect, title: "内网直连", subtitle: "800ms 竞速", latencyText: "\(store.lanLatencyMs)ms")
                }

                VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                    onboardingField(label: "公网反代地址", placeholder: InstanceProfile.placeholderPublicURL, text: $publicURL)
                    if preferredChannel == .lanDirect || !lanURL.isEmpty {
                        onboardingField(label: "内网直连地址（可选）", placeholder: InstanceProfile.placeholderLANURL, text: $lanURL)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }

    private func channelSelectorCard(channel: EndpointChannel, title: String, subtitle: String, latencyText: String) -> some View {
        let isSelected = preferredChannel == channel
        return Button {
            TeaPulseMotion.run(TeaPulseMotion.spring, reduceMotion: reduceMotion) { preferredChannel = channel }
        } label: {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                HStack(spacing: TeaPulseSpacing.xs) {
                    PulsingStatusDot(color: isSelected ? TeaPulseTheme.primary : TeaPulseTheme.secondary, animate: isSelected)
                    Text(title)
                        .font(TeaPulseTypography.bodySm)
                        .fontWeight(.semibold)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                        .lineLimit(1)
                    Spacer()
                }
                HStack(spacing: TeaPulseSpacing.xs) {
                    Text(subtitle)
                        .font(TeaPulseTypography.labelMd)
                        .foregroundStyle(TeaPulseTheme.secondary)
                        .lineLimit(1)
                    Spacer()
                    Text(latencyText)
                        .font(TeaPulseTypography.codeSm)
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? TeaPulseTheme.primary : TeaPulseTheme.secondary)
                        .lineLimit(1)
                        .teaPulseNumericTransition(value: latencyText)
                }
            }
            .padding(TeaPulseSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? TeaPulseTheme.surfaceElevated : TeaPulseTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous).stroke(isSelected ? TeaPulseTheme.primary : TeaPulseTheme.cardBorder, lineWidth: 1))
            .animation(reduceMotion ? nil : TeaPulseMotion.spring, value: preferredChannel)
        }
        .buttonStyle(TeaPulsePressableCardStyle())
    }

    private var authVaultCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                Text("PAT 凭据")
                    .font(TeaPulseTypography.headlineMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)

                HStack(spacing: TeaPulseSpacing.sm) {
                    Group {
                        if revealToken {
                            TextField("粘贴 Gitea Personal Access Token", text: $patToken)
                        } else {
                            SecureField("粘贴 Gitea Personal Access Token", text: $patToken)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(TeaPulseTypography.codeSm)
                    .foregroundStyle(TeaPulseTheme.onSurface)

                    Button {
                        revealToken.toggle()
                    } label: {
                        Image(systemName: revealToken ? "eye.slash" : "eye")
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .padding(TeaPulseSpacing.sm)
                            .frame(minWidth: 36, minHeight: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(TeaPulsePressableCardStyle())

                    Button("粘贴") {
                        if let pasted = ClipboardService.paste() {
                            patToken = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
                .padding(.horizontal, TeaPulseSpacing.sm)
                .padding(.vertical, TeaPulseSpacing.xs)
                .background(TeaPulseTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
            }
        }
    }

    private var handshakePipelineCard: some View {
        let showDiagnostics = isProbing || diagnostics.contains { $0.state != .pending }
        return SurfaceCard {
            VStack(alignment: .leading, spacing: showDiagnostics ? TeaPulseSpacing.sm : 0) {
                HStack(spacing: TeaPulseSpacing.sm) {
                    Text("链路探针")
                        .font(TeaPulseTypography.labelMd)
                        .foregroundStyle(TeaPulseTheme.secondary)
                    Spacer()
                    Button(isProbing ? "探测中…" : "测试连通性") {
                        Task { await triggerHandshakeProbe() }
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .disabled(isProbing)
                    .accessibilityIdentifier("loginProbeButton")
                }

                if showDiagnostics {
                    VStack(spacing: TeaPulseSpacing.xs) {
                        ForEach(diagnostics) { step in
                            VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                                HStack(spacing: TeaPulseSpacing.sm) {
                                    Image(systemName: iconName(for: step.state))
                                        .foregroundStyle(iconColor(for: step.state))
                                        .font(TeaPulseTypography.codeSm)
                                        .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))
                                    Text(step.title)
                                        .font(TeaPulseTypography.bodySm)
                                        .foregroundStyle(TeaPulseTheme.onSurface)
                                    Spacer()
                                }
                                Text(step.detail)
                                    .font(TeaPulseTypography.codeSm)
                                    .monospacedDigit()
                                    .foregroundStyle(iconColor(for: step.state))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, TeaPulseSpacing.lg)
                            }
                            .padding(.vertical, TeaPulseSpacing.xs)
                        }
                    }
                    .padding(TeaPulseSpacing.sm)
                    .background(TeaPulseTheme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("loginProbeResults")
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    .animation(reduceMotion ? nil : TeaPulseMotion.snappy, value: diagnostics)
                }
            }
        }
    }

    private var gatewayDisclosureCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: showGatewayOptions ? TeaPulseSpacing.sm : 0) {
                Button {
                    TeaPulseMotion.run(TeaPulseMotion.snappy, reduceMotion: reduceMotion) { showGatewayOptions.toggle() }
                } label: {
                    HStack(spacing: TeaPulseSpacing.sm) {
                        Image(systemName: "slider.horizontal.3")
                            .font(TeaPulseTypography.codeSm)
                            .foregroundStyle(TeaPulseTheme.primary)
                        Text("高级网关配置（SSH / 推送 / Access Header）")
                            .font(TeaPulseTypography.bodySm)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                        Spacer(minLength: TeaPulseSpacing.sm)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .rotationEffect(.degrees(showGatewayOptions ? 90 : 0))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TeaPulsePressableCardStyle())

                if showGatewayOptions {
                    VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                        onboardingField(label: "实例显示名称", placeholder: "Gitea", text: $displayName)
                        onboardingField(label: "独立 Git SSH 端口", placeholder: "2222", text: $sshPortText)
                        onboardingField(label: "全局推送地址", placeholder: InstanceProfile.placeholderBarkURL, text: $barkURL)
                        onboardingField(label: "网关 Header 键", placeholder: "CF-Access-Client-Id", text: $customHeaderKey)
                        if !customHeaderKey.isEmpty {
                            onboardingField(label: "网关 Header 值", placeholder: "secret", text: $customHeaderValue, secure: true)
                        }
                    }
                    .padding(.top, TeaPulseSpacing.xs)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var actionDock: some View {
        VStack(spacing: TeaPulseSpacing.sm) {
            if let connectionError {
                Text(connectionError)
                    .font(TeaPulseTypography.bodySm)
                    .foregroundStyle(TeaPulseTheme.error)
                    .accessibilityIdentifier("loginConnectionError")
            }
            Button {
                connectionTask = Task { await connectAndEnter() }
            } label: {
                HStack(spacing: TeaPulseSpacing.sm) {
                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                            .tint(TeaPulseTheme.onPrimary)
                    }
                    Text(isConnecting ? "正在握手连接…" : "验证并进入工作台")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PrimaryActionButtonStyle(fullWidth: true))
            .accessibilityIdentifier("loginPrimaryConnectButton")
            .disabled(isConnecting || isProbing)

            HStack(spacing: TeaPulseSpacing.sm) {
                Button("体验演示沙盒") {
                    store.switchToDemoMode()
                    dismiss()
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityIdentifier("loginDemoModeButton")
                .disabled(isConnecting)

                Spacer()

                if !store.isDemoMode || store.isConnectionSheetPresented {
                    Button("暂不修改") {
                        connectionTask?.cancel()
                        store.isLoginGatePresented = false
                        dismiss()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                }
            }
        }
    }

    private func triggerHandshakeProbe() async {
        isProbing = true
        var headers: [String: String] = [:]
        let cleanKey = customHeaderKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanKey.isEmpty {
            headers[cleanKey] = customHeaderValue
        }
        let result = await store.runOnboardingHandshake(
            publicURL: publicURL,
            lanURL: lanURL.isEmpty ? nil : lanURL,
            patToken: patToken,
            preferredChannel: preferredChannel,
            customHeaders: headers
        )
        TeaPulseMotion.run(TeaPulseMotion.snappy, reduceMotion: reduceMotion) {
            diagnostics = result
        }
        isProbing = false
    }

    private func connectAndEnter() async {
        isConnecting = true
        connectionError = nil
        var headers: [String: String] = [:]
        let cleanKey = customHeaderKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanKey.isEmpty {
            headers[cleanKey] = customHeaderValue
        }
        let ok = await store.connectLiveInstance(
            displayName: displayName,
            publicURL: publicURL,
            lanURL: lanURL.isEmpty ? nil : lanURL,
            patToken: patToken,
            sshPortOverride: Int(sshPortText),
            barkURL: barkURL.isEmpty ? nil : barkURL,
            preferredChannel: preferredChannel,
            customHeaders: headers
        )
        isConnecting = false
        guard !Task.isCancelled else { return }
        if ok {
            dismiss()
        } else {
            connectionError = store.statusToast ?? "连接失败，请检查地址与 PAT"
        }
    }

    @ViewBuilder
    private func onboardingField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        secure: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
            Text(label)
                .font(TeaPulseTypography.labelMd)
                .foregroundStyle(TeaPulseTheme.secondary)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .accessibilityIdentifier("onboardingField-\(label)")
            .font(TeaPulseTypography.codeSm)
            .foregroundStyle(TeaPulseTheme.onSurface)
            .padding(TeaPulseSpacing.sm)
            .background(TeaPulseTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous)
                    .stroke(TeaPulseTheme.cardBorder, lineWidth: 1)
            )
        }
    }

    private func iconName(for state: LoginDiagnosticStep.State) -> String {
        switch state {
        case .pending: return "circle"
        case .running: return "dot.radiowaves.left.and.right"
        case .passed: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    private func iconColor(for state: LoginDiagnosticStep.State) -> Color {
        switch state {
        case .pending: return TeaPulseTheme.secondary
        case .running: return TeaPulseTheme.warning
        case .passed: return TeaPulseTheme.primary
        case .warning: return TeaPulseTheme.warning
        case .failed: return TeaPulseTheme.error
        }
    }
}
