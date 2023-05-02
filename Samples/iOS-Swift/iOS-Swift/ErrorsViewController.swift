import Foundation
import Sentry
import UIKit

class ErrorsViewController: UIViewController {

    private let dispatchQueue = DispatchQueue(label: "ErrorsViewController", attributes: .concurrent)
    private let diskWriteException = DiskWriteException()

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SentrySDK.reportFullyDisplayed()
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

    @IBAction func asyncCrash(_ sender: UIButton) {
        highlightButton(sender)
        DispatchQueue.main.async {
            self.asyncCrash1()
        }
    }

    @IBAction func captureError(_ sender: UIButton) {
        highlightButton(sender)
        do {
            try RandomErrorGenerator.generate()
        } catch {
            SentrySDK.capture(error: XMLParsingError(line: 10, column: 10, kind: .internalError)) { (scope) in
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

    func highlightButton(_ sender: UIButton) {
        let originalLayerColor = sender.layer.backgroundColor
        let originalTitleColor = sender.titleColor(for: .normal)
        sender.layer.backgroundColor = UIColor.blue.cgColor
        sender.setTitleColor(.white, for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            sender.layer.backgroundColor = originalLayerColor
            sender.setTitleColor(originalTitleColor, for: .normal)
            sender.titleLabel?.textColor = originalTitleColor
        }
    }
}

struct XMLParsingError: Error {
    enum ErrorKind {
        case invalidCharacter
        case mismatchedTag
        case internalError
    }

    let line: Int
    let column: Int
    let kind: ErrorKind
}
