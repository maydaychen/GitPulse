import SwiftUI
import GiteaKit

@main
struct TeaPulseApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup(id: "main") {
            RootContainerView()
                .environment(store)
                .preferredColorScheme(store.themePreference.colorScheme)
                .onOpenURL { url in
                    store.handle(url: url)
                }
                .task {
                    store.startNetworkMonitoring()
                    await store.refreshLiveInstanceData()
                    store.consumePendingSharedRoute()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            _ = await store.refreshLiveInstanceDataIfStale()
                            store.consumePendingSharedRoute()
                        }
                    }
                }
        }
        #if os(macOS)
        .defaultSize(width: 1240, height: 820)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("命令面板") {
                    store.isCommandPalettePresented = true
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("刷新实例数据") {
                    Task { await store.refreshLiveInstanceData() }
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("实例连接配置") {
                    store.isConnectionSheetPresented = true
                }
                .keyboardShortcut(",", modifiers: [.command, .shift])
            }
        }
        #endif

        #if os(macOS)
        MenuBarExtra("TeaPulse", systemImage: "waveform.path.ecg") {
            MenuBarBuildExtraView()
                .environment(store)
                .preferredColorScheme(store.themePreference.colorScheme)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
