import SwiftUI
import WidgetKit

@main
struct SampleWidgetBundle: WidgetBundle {
    var body: some Widget {
        SampleWidget()
        SampleWidgetControl()
    }
}
