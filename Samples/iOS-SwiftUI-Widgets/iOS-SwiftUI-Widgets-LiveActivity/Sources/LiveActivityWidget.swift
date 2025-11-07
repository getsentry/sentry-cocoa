import ActivityKit
import Sentry
import SentrySampleShared
import SwiftUI
import WidgetKit

struct LiveActivityWidget: Widget {
    init() {
        setupSentrySDK()
    }
    
    private func setupSentrySDK() {
        guard !SentrySDK.isEnabled else {
            return
        }
        SentrySDK.start { options in
            options.dsn = SentrySDKWrapper.defaultDSN
            options.debug = true
            options.enableAppHangTracking = true
        }
    }
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.anrTrackingStatus)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.anrTrackingStatus)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.anrTrackingStatus.prefix(1))")
            } minimal: {
                Text(context.state.anrTrackingStatus)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}
