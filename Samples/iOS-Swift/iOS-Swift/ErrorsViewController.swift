import Foundation
import Sentry
import UIKit

class ErrorsViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    private let dispatchQueue = DispatchQueue(label: "ErrorsViewController", attributes: .concurrent)
    private let diskWriteException = DiskWriteException()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
        
        SentrySDK.metrics.increment(key: "load.errors.view.controller")
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
        SentrySDK.crash()
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
