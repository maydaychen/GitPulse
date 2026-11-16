import SwiftUI
import GiteaKit

public struct ShareTargetCardView: View {
    public let sharedURLString: String
    public let parsedRoute: TeaPulseRoute?
    public let onConfirm: () -> Void
    public let onCancel: () -> Void

    public init(
        sharedURLString: String,
        parsedRoute: TeaPulseRoute?,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.sharedURLString = sharedURLString
        self.parsedRoute = parsedRoute
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.md) {
            HStack(spacing: TeaPulseSpacing.sm) {
                Text("TeaPulse 直达路由")
                    .font(TeaPulseTypography.headlineMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                Spacer()
                StatusBadge(parsedRoute != nil ? "已识别" : "未匹配", tone: parsedRoute != nil ? .primary : .warning)
            }

            SurfaceCard {
                VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
                    Text(parsedRoute?.displayTitle ?? "无法识别 Gitea 链接")
                        .font(TeaPulseTypography.bodyMd)
                        .foregroundStyle(TeaPulseTheme.onSurface)
                    if let parsedRoute {
                        BranchRoutePill(parsedRoute.deepLinkString)
                    } else {
                        Text(sharedURLString)
                            .font(TeaPulseTypography.codeSm)
                            .foregroundStyle(TeaPulseTheme.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: TeaPulseSpacing.sm) {
                Button("取消", action: onCancel)
                    .buttonStyle(SecondaryActionButtonStyle())
                Spacer()
                Button("保存路由") {
                    if let parsedRoute {
                        AppGroupBridge.savePendingSharedRoute(
                            PendingSharedRoute(
                                deepLink: parsedRoute.deepLinkString,
                                sourceURL: sharedURLString,
                                title: parsedRoute.displayTitle
                            )
                        )
                    }
                    onConfirm()
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(parsedRoute == nil)
            }
            Text("保存后，请手动打开 TeaPulse 查看目标内容。")
                .font(TeaPulseTypography.bodySm)
                .foregroundStyle(TeaPulseTheme.secondary)
        }
        .padding(TeaPulseSpacing.lg)
        .background(TeaPulseTheme.surface)
    }
}
