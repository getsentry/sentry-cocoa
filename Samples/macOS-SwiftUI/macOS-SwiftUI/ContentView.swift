import Sentry
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Button(action: captureError) {
                Text("Capture Error")
            }
            
            Button(action: uncaughtNSException) {
                Text("Uncaught NSException")
            }
            
            Button(action: crash) {
                Text("Crash")
            }
        }
        .padding()
    }
    
    func captureError() {
        let error = NSError(domain: "SampleErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        SentrySDK.capture(error: error)
    }
    
    func uncaughtNSException() {
        NSException(name: NSExceptionName(rawValue: "ExplodingPotato"),
                    reason: "Potato is exploding!",
                    userInfo: nil).raise()
    }
    
    func crash() {
        SentrySDK.crash()
    }
}

#Preview {
    ContentView()
}
