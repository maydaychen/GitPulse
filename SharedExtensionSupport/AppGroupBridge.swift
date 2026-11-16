import Foundation
import GiteaKit

public enum AppGroupBridge {
    public static let suiteName = "group.com.maydaychen.teapulse"
    private static let widgetSnapshotKey = "teapulse.widget.snapshot.v1"
    private static let pendingRouteKey = "teapulse.share.pendingRoute.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    public static func saveWidgetSnapshot(_ snapshot: WidgetDashboardSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: widgetSnapshotKey)
    }

    public static func loadWidgetSnapshot() -> WidgetDashboardSnapshot? {
        guard let data = defaults.data(forKey: widgetSnapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetDashboardSnapshot.self, from: data)
    }

    public static func savePendingSharedRoute(_ route: PendingSharedRoute) {
        guard let data = try? JSONEncoder().encode(route) else { return }
        defaults.set(data, forKey: pendingRouteKey)
    }

    public static func consumePendingSharedRoute() -> PendingSharedRoute? {
        guard let data = defaults.data(forKey: pendingRouteKey),
              let route = try? JSONDecoder().decode(PendingSharedRoute.self, from: data) else {
            return nil
        }
        defaults.removeObject(forKey: pendingRouteKey)
        return route
    }
}
