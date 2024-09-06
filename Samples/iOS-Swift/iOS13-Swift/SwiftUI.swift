import SentrySwiftUI
import SwiftUI

struct SwiftUI: View {
    var body: some View {
        SentryTracedView("SwiftUI View") {
            Text("SwiftUI!")
        }
    }
}

struct SwiftUI_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUI()
    }
}
