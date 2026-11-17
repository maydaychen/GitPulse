import Foundation
import GiteaKit

public enum AppGroupBridge {
    public static let suiteName = "group.com.maydaychen.teapulse"
    private static let widgetSnapshotKey = "teapulse.widget.snapshot.v1"
    private static let widgetContextKey = "teapulse.widget.context.v1"
    private static let pendingRouteKey = "teapulse.share.pendingRoute.v1"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    public static func saveWidgetSnapshot(_ snapshot: WidgetDashboardSnapshot, userDefaults: UserDefaults? = nil) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        (userDefaults ?? defaults).set(data, forKey: widgetSnapshotKey)
    }

    public static func loadWidgetSnapshot(userDefaults: UserDefaults? = nil) -> WidgetDashboardSnapshot? {
        guard let data = (userDefaults ?? defaults).data(forKey: widgetSnapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetDashboardSnapshot.self, from: data)
    }

    public static func saveWidgetConnectionContext(_ context: WidgetConnectionContext, userDefaults: UserDefaults? = nil) {
        guard let data = try? JSONEncoder().encode(context) else { return }
        (userDefaults ?? defaults).set(data, forKey: widgetContextKey)
    }

    public static func loadWidgetConnectionContext(userDefaults: UserDefaults? = nil) -> WidgetConnectionContext? {
        guard let data = (userDefaults ?? defaults).data(forKey: widgetContextKey) else { return nil }
        return try? JSONDecoder().decode(WidgetConnectionContext.self, from: data)
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
