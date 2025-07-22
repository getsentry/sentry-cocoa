import SwiftUI
import WidgetKit

@main
struct SentryWidgetBundle: WidgetBundle {
    var body: some Widget {
        SentryWidget()
        SentryWidgetControl()
        SentryWidgetLiveActivity()
    }
}
