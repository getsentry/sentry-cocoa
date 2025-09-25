import Sentry
import SwiftUI

import Logging

struct ContentView: View {
    
    private func captureError() {
        Task {
            await captureErrorAsync()
        }
    }
    
    private func swiftLog() {
        let logger = Logger(label: "io.sentry.iOS15-SwiftUI")
        logger.trace(
            "swift-log",
            metadata: ["foo": "bar"],
            source: "iOS"
        )
    }
    
    func captureErrorAsync() async {
        let error = NSError(domain: "SampleErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        SentrySDK.capture(error: error)
    }
    
    var body: some View {
        VStack(alignment: HorizontalAlignment.center, spacing: 16) {
            Button(action: captureError) {
                Text("Capture Error")
            }
            Button(action: swiftLog) {
                Text("swift-log")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
