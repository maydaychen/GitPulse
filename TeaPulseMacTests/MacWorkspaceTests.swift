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
}
