import SwiftUI
import GiteaKit

public struct BarkPushConfigSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var barkEndpoint: String = ""

    public init() {}

    private var pushPayloadExample: String {
        let base = barkEndpoint.isEmpty ? InstanceProfile.placeholderBarkURL : barkEndpoint
        return """
        POST \(base)
        {"title":"Gitea CI 告警","body":"build #184 失败","url":"teapulse://actions/alex/web-deploy/184?step=failed"}
        """
    }

    public var body: some View {
        TeaPulseModalSheet(
            title: "推送设置",
            minWidth: 500,
            idealWidth: 540,
            minHeight: 340,
            idealHeight: 380,
            onClose: { dismiss() }
        ) {
            VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
                VStack(alignment: .leading, spacing: TeaPulseSpacing.xs) {
                    Text("全局推送接收地址")
                        .font(TeaPulseTypography.labelMd)
                        .foregroundStyle(TeaPulseTheme.secondary)
                    TextField(InstanceProfile.placeholderBarkURL, text: $barkEndpoint)
                        .textFieldStyle(.plain)
                        .font(TeaPulseTypography.codeSm)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                        .padding(TeaPulseSpacing.sm)
                        .background(TeaPulseTheme.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: TeaPulseRadius.md, style: .continuous).stroke(TeaPulseTheme.cardBorder, lineWidth: 1))
                }

                SurfaceCard {
                    VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                        HStack {
                            Text("推送请求示例")
                                .font(TeaPulseTypography.labelMd)
                                .foregroundStyle(TeaPulseTheme.secondary)
                            Spacer()
                            Button("复制模板") {
                                ClipboardService.copy(pushPayloadExample)
                                store.showToast("已复制推送示例")
                            }
                            .buttonStyle(SecondaryActionButtonStyle())
                        }
                        Text(pushPayloadExample)
                            .font(TeaPulseTypography.codeSm)
                            .foregroundStyle(TeaPulseTheme.onSurface)
                            .textSelection(.enabled)
                            .padding(TeaPulseSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(TeaPulseTheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: TeaPulseRadius.sm, style: .continuous)
                                    .stroke(TeaPulseTheme.cardBorder, lineWidth: 1)
                            )
                    }
                }

                HStack {
                    Button("路由自检") {
                        store.handle(deepLinkString: "teapulse://actions/alex/web-deploy/184?step=failed")
                        dismiss()
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    Spacer()
                    Button("保存地址") {
                        store.updateBarkEndpoint(barkEndpoint)
                        dismiss()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                }

                Spacer()
            }
            .padding(TeaPulseSpacing.md)
            .background(TeaPulseTheme.surface)
        }
        .onAppear {
            barkEndpoint = store.profile.barkEndpointURL ?? ""
        }
    }
}
