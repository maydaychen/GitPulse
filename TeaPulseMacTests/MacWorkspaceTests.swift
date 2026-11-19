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

    @Test("Split workspace enables master-detail only for repos and actions")
    func splitWorkspaceRoutingUsesSingleCanvasForOverviewInboxAndOps() {
        #expect(AppSection.repos.usesMasterDetailSplit == true)
        #expect(AppSection.actions.usesMasterDetailSplit == true)
        #expect(AppSection.pulse.usesMasterDetailSplit == false)
        #expect(AppSection.inbox.usesMasterDetailSplit == false)
        #expect(AppSection.ops.usesMasterDetailSplit == false)
    }

    @Test("Sidebar version badge formats unreachable, unloaded, and release versions cleanly")
    func formatsSidebarVersionBadgeAndThemeIcons() {
        let offline = EndpointHealth(channel: .publicProxy, baseURL: "https://git.example.com", latencyMs: 0, serverVersion: "unreachable").sidebarVersionBadge
        #expect(offline.label == "离线")
        #expect(offline.tone == .error)

        let pending = EndpointHealth(channel: .publicProxy, baseURL: "", latencyMs: 0, serverVersion: "未加载").sidebarVersionBadge
        #expect(pending.label == "待连接")
        #expect(pending.tone == .neutral)

        let live = EndpointHealth(channel: .lanDirect, baseURL: "http://10.0.0.2:3000", latencyMs: 4, serverVersion: "1.27.3+rc1-g1234").sidebarVersionBadge
        #expect(live.label == "v1.27.3")
        #expect(live.tone == .primary)

        #expect(ThemePreference.allCases.map(\.iconName) == ["circle.lefthalf.filled", "moon.stars.fill", "sun.max.fill"])
    }
}
