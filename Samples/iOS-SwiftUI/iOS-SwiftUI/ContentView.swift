import Sentry
import SentrySwiftUI
import SwiftUI

//This is for test purpose
class DataBag {

    static let shared = DataBag()

    var info = [String: Any]()

    private init() {
    }
}

struct ContentView: View {

    var addBreadcrumbAction: () -> Void = {
        let crumb = Breadcrumb(level: SentryLevel.info, category: "Debug")
        crumb.message = "tapped addBreadcrumb"
        crumb.type = "user"
        SentrySDK.addBreadcrumb(crumb)
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

    func getCurrentTracer() -> SentryTracer? {
        if DataBag.shared.info["initialTransaction"] == nil {
            DataBag.shared.info["initialTransaction"] = SentrySDK.span as? SentryTracer
        }
        return DataBag.shared.info["initialTransaction"] as? SentryTracer
    }

    func getCurrentSpan() -> Span? {

        let tracker = SentryPerformanceTracker.shared
        guard let currentSpanId = tracker.activeSpanId() else {
            return DataBag.shared.info["lastSpan"] as? Span
        }

        if DataBag.shared.info["lastSpan"] == nil {
            let span = tracker.getSpan(currentSpanId)

            if !(span is SentryTracer) {
                DataBag.shared.info["lastSpan"] = span
            }
        }

        return DataBag.shared.info["lastSpan"] as? Span
    }

    var body: some View {
        return SentryTracedView("Content View Body") {
            NavigationView {
                VStack(alignment: HorizontalAlignment.center, spacing: 16) {
                    Text(getCurrentTracer()?.transactionContext.name ?? "NO SPAN")
                        .accessibilityIdentifier("TRANSACTION_NAME")
                    Text(getCurrentTracer()?.transactionContext.spanId.sentrySpanIdString ?? "NO ID")
                        .accessibilityIdentifier("TRANSACTION_ID")
                    
                    Text(getCurrentTracer()?.transactionContext.origin ?? "NO ORIGIN")
                        .accessibilityIdentifier("TRACE_ORIGIN")
                    
                    SentryTracedView("Child Span") {
                        VStack {
                            Text(getCurrentSpan()?.spanDescription ?? "NO SPAN")
                                .accessibilityIdentifier("CHILD_NAME")
                            Text(getCurrentSpan()?.parentSpanId?.sentrySpanIdString ?? "NO SPAN")
                                .accessibilityIdentifier("CHILD_PARENT_SPANID")
                            
                            Text(getCurrentSpan()?.origin ?? "NO CHILD ORIGIN")
                                .accessibilityIdentifier("CHILD_TRACE_ORIGIN")
                        }
                    }
                    HStack (spacing:30) {
                        VStack(spacing: 16) {

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

                        }
                        VStack(spacing: 16) {
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
                            
                            NavigationLink(destination: SecondView()) {
                                Text("Show Detail View 1")
                            }
                            
                            NavigationLink(destination: LoremIpsumView()) {
                                Text("Lorem Ipsum")
                            }
                            
                            NavigationLink(destination: UIKitScreen()) {
                                Text("UIKit Screen")
                            }
                            
                            NavigationLink(destination: FormScreen()) {
                                Text("Form Screen")
                            }
                        }
                    }
                    SecondView()
                }
            }
        }
    }
}

struct SecondView: View {
    var body: some View {
        SentryTracedView("Second View") {
            Text("This is the detail view 1")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
