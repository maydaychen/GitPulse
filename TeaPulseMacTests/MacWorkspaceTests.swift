import Foundation
import Testing
@testable import GiteaKit

@MainActor
@Suite("TeaPulseMacWorkspaceTests")
struct MacWorkspaceTests {
    @Test("Command palette includes repositories, PRs, runs, and runners")
    func buildsCommandPalette() async {
        let store = AppStore(credentialStore: InMemoryCredentialStore(), forceDemoMode: true)
        let entries = store.commandPaletteEntries
        #expect(entries.contains { $0.badge == "合并请求" && $0.deepLink == "teapulse://pull/alex/teapulse-core/42" })
        #expect(entries.contains { $0.badge == "运维" && $0.deepLink == "teapulse://ops/runners" })

        await store.generateRunnerRegistrationToken()
        #expect(store.lastRunnerRegistrationToken?.hasPrefix("tp_reg_demo_") == true)
    }

    @Test("AppGroupBridge saves and consumes PendingSharedRoute")
    func bridgesSharedRoute() {
        let route = PendingSharedRoute(
            deepLink: "teapulse://pull/alex/teapulse-core/42",
            sourceURL: "https://git.teapulse.example:8443/alex/teapulse-core/pulls/42",
            title: "alex/teapulse-core PR #42"
        )
        AppGroupBridge.savePendingSharedRoute(route)
        let consumed = AppGroupBridge.consumePendingSharedRoute()
        #expect(consumed?.deepLink == route.deepLink)
        #expect(AppGroupBridge.consumePendingSharedRoute() == nil)
    }

    @Test("WidgetLiveRefresher reloads demo context and preserves heatmap and triage items")
    func refreshesWidgetSnapshotFromSharedContext() async {
        let suiteName = "teapulse.macwidget.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let context = WidgetConnectionContext(
            profileID: "demo-gitea",
            displayName: "Demo Gitea",
            publicURL: "https://git.teapulse.example:8443",
            username: "alex",
            isDemoMode: true
        )
        AppGroupBridge.saveWidgetConnectionContext(context, userDefaults: defaults)
        let refreshedAt = Date(timeIntervalSince1970: 1_795_000_000)

        let updated = await WidgetLiveRefresher.refreshFromSharedContext(
            forceDemoTimestampUpdate: true,
            credentialStore: InMemoryCredentialStore(),
            userDefaults: defaults,
            now: refreshedAt
        )

        #expect(updated?.updatedAt == refreshedAt)
        #expect(updated?.heatmapDays.count == 112)
        #expect(updated?.triageItems.isEmpty == false)
        #expect(AppGroupBridge.loadWidgetSnapshot(userDefaults: defaults)?.updatedAt == refreshedAt)
    }
}
