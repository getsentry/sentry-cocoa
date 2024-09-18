import Cocoa
import Sentry
import SwiftUI

class ViewController: NSViewController {

    private let diskWriteException = DiskWriteException()
    
    @IBAction func addBreadCrumb(_ sender: Any) {
        let crumb = Breadcrumb(level: SentryLevel.info, category: "Debug")
        crumb.message = "tapped addBreadcrumb"
        crumb.type = "user"
        SentrySDK.addBreadcrumb(crumb)
    }
    
    @IBAction func captureMessage(_ sender: Any) {    
        let eventId = SentrySDK.capture(message: "Yeah captured a message")
        // Returns eventId in case of successfull processed event
        // otherwise nil
        print("\(String(describing: eventId))")
    }
    
    @IBAction func captureError(_ sendder: Any) {
        let error = NSError(domain: "SampleErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Object does not exist"])
        SentrySDK.capture(error: error) { (scope) in
            scope.setTag(value: "value", key: "myTag")
        }
    }
    
    @IBAction func captureException(_ sender: Any) {
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User clicked the button", userInfo: nil)
        let scope = Scope()
        scope.setLevel(.fatal)
        SentrySDK.capture(exception: exception, scope: scope)
    }
    
    @IBAction func captureUserFeedback(_ sender: Any) {
        let error = NSError(domain: "UserFeedbackErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey: "This never happens."])

        let eventId = SentrySDK.capture(error: error) { scope in
            scope.setLevel(.fatal)
        }
        
        let userFeedback = UserFeedback(eventId: eventId)
        userFeedback.comments = "It broke on macOS-Swift. I don't know why, but this happens."
        userFeedback.email = "john@me.com"
        userFeedback.name = "John Me"
        SentrySDK.capture(userFeedback: userFeedback)
    }

    @IBAction func crashOnException(_ sender: Any) {
        let userInfo: [String: String] = ["user-info-key-1": "user-info-value-1", "user-info-key-2": "user-info-value-2"]
        let exception = NSException(name: NSExceptionName("My Custom exception"), reason: "User clicked the button", userInfo: userInfo)
        NSApplication.shared.reportException(exception)
    }
    
    @IBAction func captureTransaction(_ sender: Any) {
        let transaction = SentrySDK.startTransaction(name: "Some Transaction", operation: "some operation")
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.4...0.6), execute: {
            transaction.finish()
        })
    }
    
    @IBAction func sentryCrash(_ sender: Any) {
        SentrySDK.crash()
    }
    
    @IBAction func cppException(_ sender: Any) {
        let wrapper = CppWrapper()
        wrapper.throwCPPException()
    }
    
    @IBAction func rethrowNoActiveCppException(_ sender: Any) {
        let wrapper = CppWrapper()
        wrapper.rethrowNoActiveCPPException()
    }
    
    @IBAction func asyncCrash(_ sender: Any) {
        DispatchQueue.main.async {
            self.asyncCrash1()
        }
    }
    
    @IBAction func diskWriteException(_ sender: Any) {
        diskWriteException.continuouslyWriteToDisk()
        // As we are writing to disk continuously we would keep adding spans to this UIEventTransaction.
        SentrySDK.span?.finish()
    }
    
    @IBAction func showSwiftUIView(_ sender: Any) {
        let controller = NSHostingController(rootView: SwiftUIView())
        let window = NSWindow(contentViewController: controller)
        window.setContentSize(NSSize(width: 300, height: 200))
        let windowController = NSWindowController(window: window)
        windowController.showWindow(self)
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
}
