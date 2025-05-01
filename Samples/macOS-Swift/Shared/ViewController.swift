import Cocoa
import Sentry
import SwiftUI

class ViewController: NSViewController {

    private let diskWriteException = DiskWriteException()

    @IBOutlet weak var uiTestDataMarshalingField: NSTextField!

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
        let exception = NSException(name: NSExceptionName("My Custom exception"), reason: "User clicked the button", userInfo: nil)
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

    @IBAction func raiseNSException(_ sender: Any) {
        let userInfo: [String: String] = ["user-info-key-1": "user-info-value-1", "user-info-key-2": "user-info-value-2"]
        let exception = NSException(name: NSExceptionName("NSException via NSException raise"), reason: "Raised NSException", userInfo: userInfo)
        exception.raise()
    }

    @IBAction func reportNSException(_ sender: Any) {
        let userInfo: [String: String] = ["user-info-key-1": "user-info-value-1", "user-info-key-2": "user-info-value-2"]
        let exception = NSException(name: NSExceptionName("NSException via NSApplication report"), reason: "It doesn't work", userInfo: userInfo)
        NSApplication.shared.reportException(exception)
    }

    @IBAction func throwNSRangeException(_ sender: Any) {
        CppWrapper().throwNSRangeException()
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

    @IBAction func stopProfile(_ sender: Any) {
        SentrySDK.stopProfiler()
    }

    @IBAction func retrieveProfileChunk(_ sender: Any) {
        uiTestDataMarshalingField.stringValue = "<fetching...>"
        withProfile(continuous: true) { file in
            handleContents(file: file)
        }
    }

    var sentryBasePath: String {
        let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        let bundleIdentifier = Bundle.main.bundleIdentifier!
        let sandboxedCachesDirectory: String
        if cachesDirectory.contains(bundleIdentifier) {
            sandboxedCachesDirectory = cachesDirectory
        } else {
            sandboxedCachesDirectory = (cachesDirectory as NSString).appendingPathComponent(bundleIdentifier)
        }
        return (sandboxedCachesDirectory as NSString).appendingPathComponent("io.sentry")
    }

    func withProfile(continuous: Bool, block: (URL?) -> Void) {
        let fm = FileManager.default
        let dir = (sentryBasePath as NSString).appendingPathComponent(continuous ? "continuous-profiles" : "trace-profiles")
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: dir, isDirectory: &isDirectory), isDirectory.boolValue else {
            block(nil)
            return
        }

        let count = try! fm.contentsOfDirectory(atPath: dir).count
        //swiftlint:disable empty_count
        guard continuous || count > 0 else {
            //swiftlint:enable empty_count
            uiTestDataMarshalingField.stringValue = "<missing>"
            return
        }
        let fileName = "profile\(continuous ? 0 : count - 1)"
        let fullPath = "\(dir)/\(fileName)"

        if fm.fileExists(atPath: fullPath) {
            let url = NSURL.fileURL(withPath: fullPath)
            block(url)
            do {
                try fm.removeItem(atPath: fullPath)
            } catch {
                SentrySDK.capture(error: error)
            }
            return
        }

        block(nil)
    }

    func handleContents(file: URL?) {
        guard let file = file else {
            uiTestDataMarshalingField.stringValue = "<missing>"
            return
        }

        do {
            let data = try Data(contentsOf: file)
            let contents = data.base64EncodedString()
            print("[iOS-Swift] [debug] [ProfilingViewController] contents of file at \(file): \(String(describing: String(data: data, encoding: .utf8)))")
            uiTestDataMarshalingField.stringValue = contents
        } catch {
            SentrySDK.capture(error: error)
            uiTestDataMarshalingField.stringValue = "<empty>"
        }
    }

    @IBAction func checkProfileMarkerFileExistence(_ sender: Any) {
        let launchProfileMarkerPath = (sentryBasePath as NSString).appendingPathComponent("profileLaunch")
        if FileManager.default.fileExists(atPath: launchProfileMarkerPath) {
            uiTestDataMarshalingField.stringValue = "<exists>"
        } else {
            uiTestDataMarshalingField.stringValue = "<missing>"
        }
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
