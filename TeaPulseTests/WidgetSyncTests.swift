import Foundation
import Testing
@testable import TeaPulse
@testable import GiteaKit

@MainActor
@Suite("TeaPulseWidgetSyncTests")
struct WidgetSyncTests {
    @Test("Syncs non-secret connection context, 112-day heatmap, and priority triage to AppGroupBridge")
    func syncsWidgetContextAndRichSnapshot() {
        let suiteName = "teapulse.widgetsync.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppStore(
            credentialStore: InMemoryCredentialStore(),
            forceDemoMode: true,
            defaults: UserDefaults(suiteName: "teapulse.widgetstore.\(UUID().uuidString)")!,
            writesWidgetSnapshot: false
        )

        store.buildAndSyncWidgetState(userDefaults: defaults)

        let savedContext = AppGroupBridge.loadWidgetConnectionContext(userDefaults: defaults)
        #expect(savedContext?.profileID == "demo-gitea")
        #expect(savedContext?.username == "alex")
        #expect(savedContext?.isDemoMode == true)

        let savedSnapshot = AppGroupBridge.loadWidgetSnapshot(userDefaults: defaults)
        #expect(savedSnapshot?.instanceName == "TeaPulse")
        #expect(savedSnapshot?.heatmapDays.count == 112)
        #expect(savedSnapshot?.triageItems.count == 3)
        #expect(savedSnapshot?.triageItems.first?.deepLink == "teapulse://pull/alex/teapulse-core/42")
    }

    @Test("Navigates back to Pulse dashboard when opening teapulse://pulse from CommitHeatmapWidget")
    func navigatesToPulseRoute() {
        let store = AppStore(
            credentialStore: InMemoryCredentialStore(),
            forceDemoMode: true,
            defaults: UserDefaults(suiteName: "teapulse.pulseroute.\(UUID().uuidString)")!,
            writesWidgetSnapshot: false
        )
        store.selectedSection = .repos
        store.handle(deepLinkString: "teapulse://pulse")
        #expect(store.selectedSection == .pulse)
    }
}
