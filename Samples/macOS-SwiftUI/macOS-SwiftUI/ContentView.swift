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
                var dict = [HashableViolation(): "value"]

                // Add plenty of items to the dictionary so it uses both == and hash methods, which will cause the crash.
                for i in 0..<1_000_000 {
                    dict[HashableViolation()] = "value \(i)"
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

/// When using this class with a dictionary in Swift, it will cause a crash due to the violation of the Hashable contract.
/// The Swift dict sees multiple keys that are equal but have different hashes, which it can’t resolve safely. When this
/// happens, the Swift runtime will crash with the error: "Fatal error: Duplicate keys of type 'HashableViolation' were
/// found in a Dictionary."
class HashableViolation: Hashable {

    //  always return true, which means every instance of Something is considered equal.
    static func == (lhs: HashableViolation, rhs: HashableViolation) -> Bool {
        return true
    }

    // Always return a different hash value for each instance so we're violating the Hashable contract.
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

#Preview {
    ContentView()
}
