import Foundation
import Sentry
import UIKit

class ErrorsViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    private let dispatchQueue = DispatchQueue(label: "ErrorsViewController", attributes: .concurrent)
    private let diskWriteException = DiskWriteException()
    
    @IBOutlet weak var dsnView: UIView!
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
        addDSNDisplay(self, vcview: dsnView)
    }

    @IBAction func useAfterFree(_ sender: UIButton) {
        imageView.image = UIImage(named: "")
    }

    @IBAction func diskWriteException(_ sender: UIButton) {
        highlightButton(sender)
        diskWriteException.continuouslyWriteToDisk()

        // As we are writing to disk continuously we would keep adding spans to this UIEventTransaction.
        SentrySDK.span?.finish()
    }

    @IBAction func crash(_ sender: UIButton) {
        let transaction = SentrySDK.startTransaction(name: "Crashing Transaction", operation: "ui.load", bindToScope: true)
        
        transaction.startChild(operation: "operation explode")
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            transaction.startChild(operation: "operation crash")
            SentrySDK.crash()
        }
    }

    // swiftlint:disable force_unwrapping
    @IBAction func unwrapCrash(_ sender: UIButton) {
        highlightButton(sender)
        let a: String! = nil
        let b: String = a!
        print(b)
    }
    // swiftlint:enable force_unwrapping

    @IBAction func captureError(_ sender: UIButton) {
        highlightButton(sender)
        do {
            try RandomErrorGenerator.generate()
        } catch {
            SentrySDK.capture(error: error) { (scope) in
                // Changes in here will only be captured for this event
                // The scope in this callback is a clone of the current scope
                // It contains all data but mutations only influence the event being sent
                scope.setTag(value: "value", key: "myTag")
            }
            
            if !ProcessInfo.processInfo.arguments.contains("--io.sentry.iOS-Swift.auto-inject-user-feedback-widget") {
                let alert = UIAlertController(title: "Uh-oh!", message: "There was an error. Would you like to tell us what happened?", preferredStyle: .alert)
                alert.addAction(.init(title: "Yes", style: .default, handler: { _ in
                    SentrySDK.showUserFeedbackForm()
                }))
                alert.addAction(.init(title: "No", style: .cancel))
                self.present(alert, animated: true)
            }
        }
    }

    @IBAction func captureNSException(_ sender: UIButton) {
        highlightButton(sender)
        let exception = NSException(name: NSExceptionName("My Custom exeption"), reason: "User clicked the button", userInfo: nil)
        let scope = Scope()
        scope.setLevel(.fatal)
        // !!!: By explicity just passing the scope, only the data in this scope object will be added to the event; the global scope (calls to configureScope) will be ignored. If you do that, be careful–a lot of useful info is lost. If you just want to mutate what's in the scope use the callback, see: captureError.
        SentrySDK.capture(exception: exception, scope: scope)
    }

    @IBAction func captureFatalError(_ sender: UIButton) {
        highlightButton(sender)
        fatalError("This is a fatal error. Oh no 😬.")
    }

    @IBAction func oomCrash(_ sender: UIButton) {
        highlightButton(sender)
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
}
