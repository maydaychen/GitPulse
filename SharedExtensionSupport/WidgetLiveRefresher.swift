import Foundation
import GiteaKit

/// Coordinates autonomous snapshot refreshes inside Widget extensions and test targets.
public enum WidgetLiveRefresher {
    @discardableResult
    public static func refreshFromSharedContext(
        forceDemoTimestampUpdate: Bool = false,
        transport: HTTPTransport = URLSessionHTTPTransport(),
        credentialStore: CredentialStore? = nil,
        userDefaults: UserDefaults? = nil,
        now: Date = Date()
    ) async -> WidgetDashboardSnapshot? {
        let resolvedStore: CredentialStore
        if let credentialStore {
            resolvedStore = credentialStore
        } else {
            #if os(macOS)
            resolvedStore = KeychainCredentialStore(allowLegacyFallback: false)
            #else
            resolvedStore = KeychainCredentialStore(allowLegacyFallback: true)
            #endif
        }

        let context = AppGroupBridge.loadWidgetConnectionContext(userDefaults: userDefaults)
        let cached = AppGroupBridge.loadWidgetSnapshot(userDefaults: userDefaults)
        let service = WidgetSnapshotService(transport: transport)
        let updated = await service.refreshSnapshot(
            context: context,
            credentialStore: resolvedStore,
            cachedSnapshot: cached,
            forceDemoTimestampUpdate: forceDemoTimestampUpdate,
            now: now
        )
        if let updated {
            AppGroupBridge.saveWidgetSnapshot(updated, userDefaults: userDefaults)
        }
        return updated
    }
}
