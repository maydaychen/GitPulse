#if os(macOS)
import SwiftUI
import GiteaKit

public struct MenuBarBuildExtraView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: TeaPulseSpacing.sm) {
            HStack {
                Text("TeaPulse")
                    .font(TeaPulseTypography.headlineMd)
                    .foregroundStyle(TeaPulseTheme.onSurface)
                Spacer()
                StatusBadge(store.health.probePillText, tone: .primary)
            }

            Divider()

            let runningCount = store.runs.filter { $0.status == .running }.count
            let failedCount = store.runs.filter { $0.status == .failure }.count
            let onlineRunners = store.runners.filter { $0.status != .offline }.count

            Text("构建：\(runningCount) 运行中 · \(failedCount) 失败")
                .font(TeaPulseTypography.codeSm)
                .monospacedDigit()
                .foregroundStyle(failedCount > 0 ? TeaPulseTheme.error : TeaPulseTheme.onSurface)

            Text("执行节点：\(onlineRunners)/\(store.runners.count) 在线")
                .font(TeaPulseTypography.codeSm)
                .monospacedDigit()
                .foregroundStyle(TeaPulseTheme.secondary)

            Divider()

            if let failedRun = store.runs.first(where: { $0.status == .failure }) {
                Button("直达失败构建 #\(failedRun.runNumber)") {
                    store.handle(deepLinkString: "teapulse://actions/\(failedRun.repoFullName)/\(failedRun.runNumber)?step=failed")
                    openWindow(id: "main")
                }
            }

            Button("打开命令面板 ⌘K") {
                store.isCommandPalettePresented = true
                openWindow(id: "main")
            }

            Button("立即刷新链路探针") {
                Task { await store.refreshEndpointProbe() }
            }
        }
        .padding(TeaPulseSpacing.md)
        .frame(width: 260)
    }
}
#endif
