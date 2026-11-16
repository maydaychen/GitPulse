import WidgetKit
import SwiftUI

@main
struct TeaPulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        PulseStatusWidget()
        #if canImport(ActivityKit) && os(iOS)
        BuildLiveActivityWidget()
        #endif
    }
}
