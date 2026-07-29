import SentrySwiftUI
import SwiftUI

struct SwiftUIView: View {
    var body: some View {
        SentryTracedView("SwiftUI View (macOS)") {
            Text("SwiftUI!")
        }
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIView()
    }
}
