import ActivityKit
import SwiftUI
import WidgetKit

struct SentryWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct SentryWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SentryWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
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
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension SentryWidgetAttributes {
    fileprivate static var preview: SentryWidgetAttributes {
        SentryWidgetAttributes(name: "World")
    }
}

extension SentryWidgetAttributes.ContentState {
    fileprivate static var smiley: SentryWidgetAttributes.ContentState {
        SentryWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: SentryWidgetAttributes.ContentState {
         SentryWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: SentryWidgetAttributes.preview) {
   SentryWidgetLiveActivity()
} contentStates: {
    SentryWidgetAttributes.ContentState.smiley
    SentryWidgetAttributes.ContentState.starEyes
}
