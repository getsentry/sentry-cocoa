import Sentry
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Button("CaptureMessage") {
                SentrySDK.capture(message: "Yeah captured a message")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
