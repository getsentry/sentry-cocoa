import Sentry
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Button(action: captureError) {
                Text("Capture Error")
            }
            
            Button(action: raiseNSException) {
                Text("Raise NSException")
            }
            
            Button(action: reportNSException) {
                Text("Report NSException")
            }

            Button(action: {
                // Triggers: Fatal error: Duplicate keys of type 'Something' were found in a Dictionary.
                var dict = [Something(): "value", Something(): "value"]

                for _ in 0..<100 {
                    dict[Something()] = "value \(1)"
                }
            }) {
                Text("Fatal Duplicate Key Error")
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
    
    func raiseNSException() {
        let userInfo: [String: String] = ["user-info-key-1": "user-info-value-1", "user-info-key-2": "user-info-value-2"]
        let exception = NSException(name: NSExceptionName("NSException via NSException raise"), reason: "Raised NSException", userInfo: userInfo)
        exception.raise()
    }
    
    func reportNSException() {
        let userInfo: [String: String] = ["user-info-key-1": "user-info-value-1", "user-info-key-2": "user-info-value-2"]
        let exception = NSException(name: NSExceptionName("NSException via NSApplication report"), reason: "It doesn't work", userInfo: userInfo)
        NSApplication.shared.reportException(exception)
    }
    
    func crash() {
        SentrySDK.crash()
    }
}

class Something: Hashable {

    private var x: Int = 0

    static func == (lhs: Something, rhs: Something) -> Bool {
        return true
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(Int.random(in: 0..<100))
    }
}

#Preview {
    ContentView()
}
