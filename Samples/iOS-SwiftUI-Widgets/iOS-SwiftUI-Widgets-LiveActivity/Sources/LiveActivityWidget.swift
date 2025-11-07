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
            VStack(alignment: .leading, spacing: 8) {
                Text("Sentry")
                    .font(.headline)

                Text("SDK Enabled? \(isSentryEnabled ? "✅" : "❌")")
                    .font(.caption)
                    .foregroundColor(isSentryEnabled ? .green : .red)
                    .bold()

                Text("ANR Disabled? \(!isANRTrackingEnabled ? "✅" : "❌")")
                    .font(.caption2)
                    .foregroundColor(!isANRTrackingEnabled ? .green : .red)
                    .bold()

                Text(context.state.timestamp, style: .time)
                    .font(.caption2)
            }
            .padding()

        } dynamicIsland: { _ in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("SDK Enabled? \(isSentryEnabled ? "✅" : "❌")")
                        .font(.caption)
                        .foregroundColor(isSentryEnabled ? .green : .red)
                        .bold()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("ANR Disabled? \(!isANRTrackingEnabled ? "✅" : "❌")")
                        .font(.caption2)
                        .foregroundColor(!isANRTrackingEnabled ? .green : .red)
                        .bold()
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("SDK Enabled? \(isSentryEnabled ? "✅" : "❌")")
                        .font(.caption)
                        .foregroundColor(isSentryEnabled ? .green : .red)
                        .bold()
                    Text("ANR Disabled? \(!isANRTrackingEnabled ? "✅" : "❌")")
                        .font(.caption2)
                        .foregroundColor(!isANRTrackingEnabled ? .green : .red)
                        .bold()
                }
            } compactLeading: {
                Text(isSentryEnabled ? "✅" : "❌")
            } compactTrailing: {
                Text(!isANRTrackingEnabled ? "✅" : "❌")
            } minimal: {
                Text("\(isSentryEnabled ? "✅" : "❌") - \(!isANRTrackingEnabled ? "✅" : "❌")")
            }
            .widgetURL(URL(string: "http://sentry.io"))
            .keylineTint(isSentryEnabled && !isANRTrackingEnabled ? .green : .red)
        }
    }

    var isSentryEnabled: Bool {
        return SentrySDK.isEnabled
    }

    var isANRTrackingEnabled: Bool {
        return isSentryEnabled && SentrySDKInternal.trimmedInstalledIntegrationNames().contains("ANRTracking")
    }
}
