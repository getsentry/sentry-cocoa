import SentrySwiftUI
import SwiftUI

@available(macOS 10.15, *)
struct SwiftUIView: View {
    var body: some View {
        SentryTracedView("SwiftUI View (macOS)") {
            Text("SwiftUI!")
        }
    }
}

@available(macOS 10.15, *)
struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIView()
    }
}
