import ActivityKit
import Sentry
import SwiftUI
import WidgetKit

struct LiveActivityConfiguration: Widget {
    
    init() {
        setupSentrySDK()
    }
    
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivityAttributes.self) { context in
            // Lock screen/banner UI
            VStack(alignment: .leading, spacing: 8) {
                Text("Sentry")
                    .font(.headline)
                
                Text("ANR Tracking:")
                    .font(.caption2)
                Text(context.state.anrTrackingStatus == "Enabled" ? "❌ Enabled" : "✅ Disabled")
                    .font(.caption)
                    .foregroundColor(context.state.anrTrackingStatus == "Enabled" ? .red : .green)
                    .bold()
                
                Text(context.state.timestamp, style: .time)
                    .font(.caption2)
            }
            .padding()
            .activityBackgroundTint(Color.blue.opacity(0.1))
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view when tapped
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sentry")
                            .font(.headline)
                        Text("ANR Tracking")
                            .font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(context.state.anrTrackingStatus == "Enabled" ? "❌ Enabled" : "✅ Disabled")
                            .font(.caption)
                            .foregroundColor(context.state.anrTrackingStatus == "Enabled" ? .red : .green)
                            .bold()
                        Text(context.state.timestamp, style: .time)
                            .font(.caption2)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("ANR tracking is \(context.state.anrTrackingStatus.lowercased()) in Live Activities")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            } compactLeading: {
                // Compact leading - show icon
                Image(systemName: context.state.anrTrackingStatus == "Enabled" ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundColor(context.state.anrTrackingStatus == "Enabled" ? .red : .green)
            } compactTrailing: {
                // Compact trailing - show status text
                Text(context.state.anrTrackingStatus == "Enabled" ? "ANR" : "OK")
                    .font(.caption2)
                    .foregroundColor(context.state.anrTrackingStatus == "Enabled" ? .red : .green)
            } minimal: {
                // Minimal view - just icon
                Image(systemName: context.state.anrTrackingStatus == "Enabled" ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundColor(context.state.anrTrackingStatus == "Enabled" ? .red : .green)
            }
        }
    }
    
    private func setupSentrySDK() {
        guard !SentrySDK.isEnabled else {
            return
        }
        SentrySDK.start { options in
            options.dsn = "https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.enableAppHangTracking = true
        }
    }
}
