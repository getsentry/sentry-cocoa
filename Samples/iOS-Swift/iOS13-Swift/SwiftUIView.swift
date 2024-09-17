import SentrySwiftUI
import SwiftUI

struct SwiftUIView: View {
    var body: some View {
        SentryTracedView("SwiftUI View") {
            VStack {
                Text("Welcome")
                    .replayRedact()
                Text("SwiftUI!")
            }
            .background(Color.green)
        }
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIView()
    }
}
