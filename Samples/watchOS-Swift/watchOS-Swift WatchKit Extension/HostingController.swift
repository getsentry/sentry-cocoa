import Foundation
import SwiftUI
import WatchKit

@available(watchOSApplicationExtension 7.0, *)
class HostingController: WKHostingController<ContentView> {
    override var body: ContentView {
        return ContentView()
    }
}
