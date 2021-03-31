import Sentry
import SwiftUI

struct ContentView: View {
    var addBreadcrumbAction: () -> Void = {
        let crumb = Breadcrumb(level: SentryLevel.info, category: "Debug")
        crumb.message = "tapped addBreadcrumb"
        crumb.type = "user"
        SentrySDK.addBreadcrumb(crumb: crumb)
    }
    
    var captureMessageAction: () -> Void = {
        SentrySDK.capture(message: "Yeah captured a message")
    }
    
    var captureUserFeedbackAction: () -> Void = {
        let error = NSError(domain: "UserFeedbackErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey: "This never happens."])

        let eventId = SentrySDK.capture(error: error) { scope in
            scope.setLevel(.fatal)
        }
        
        let userFeedback = UserFeedback(eventId: eventId)
        userFeedback.comments = "It broke on tvOS-Swift. I don't know why, but this happens."
        userFeedback.email = "john@me.com"
        userFeedback.name = "John Me"
        SentrySDK.capture(userFeedback: userFeedback)
    }
    
    var captureErrorAction: () -> Void = {
        let error = NSError(domain: "SampleErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        SentrySDK.capture(error: error) { (scope) in
            scope.setTag(value: "value", key: "myTag")
        }
    }
    
    var captureNSExceptionAction: () -> Void = {
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User clicked the button", userInfo: nil)
        let scope = Scope()
        scope.setLevel(.fatal)
        SentrySDK.capture(exception: exception, scope: scope)
    }
    
    var captureTransactionAction: () -> Void = {
        let transaction = SentrySDK.startTransaction(name: "Some Transaction", operation: "some operation")
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.4...0.6), execute: {
            transaction.finish()
        })
    }

    func asyncCrash1() {
        DispatchQueue.main.async {
            self.asyncCrash2()
        }
    }

    func asyncCrash2() {
        DispatchQueue.main.async {
            SentrySDK.crash()
        }
    }

    var oomCrashAction: () -> Void = {
        DispatchQueue.main.async {
            let megaByte = 1_024 * 1_024
            let memoryPageSize = NSPageSize()
            let memoryPages = megaByte / memoryPageSize

            while true {
                // Allocate one MB and set one element of each memory page to something.
                let ptr = UnsafeMutablePointer<Int8>.allocate(capacity: megaByte)
                for i in 0..<memoryPages {
                    ptr[i * memoryPageSize] = 40
                }
            }
        }
    }

    var body: some View {
        VStack {
            Button(action: addBreadcrumbAction) {
                Text("Add Breadcrumb")
            }
            
            Button(action: captureMessageAction) {
                Text("Capture Message")
            }
            
            Button(action: captureUserFeedbackAction) {
                Text("Capture User Feedback")
            }
            
            Button(action: captureErrorAction) {
                Text("Capture Error")
            }
            
            Button(action: captureNSExceptionAction) {
                Text("Capture NSException")
            }
            
            Button(action: captureTransactionAction) {
                Text("Capture Transaction")
            }

            Button(action: {
                SentrySDK.crash()
            }) {
                Text("Crash")
            }
            
            Button(action: {
                DispatchQueue.main.async {
                    self.asyncCrash1()
                }
            }) {
                Text("Async Crash")
            }

            Button(action: oomCrashAction) {
                Text("OOM Crash")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
