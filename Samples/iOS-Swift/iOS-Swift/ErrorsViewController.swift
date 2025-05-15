import Foundation
import Sentry
import SentrySampleShared
import UIKit

class ErrorsViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    private let dispatchQueue = DispatchQueue(label: "ErrorsViewController", attributes: .concurrent)
    private let diskWriteException = DiskWriteException()
    
    @IBOutlet weak var dsnView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        addDSNDisplay(self, vcview: dsnView)

        if SentrySDKOverrides.Feedback.useCustomFeedbackButton.boolValue {
            let button = SentrySDKWrapper.shared.feedbackButton
            view.addSubview(button)
            button.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8).isActive = true
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8).isActive = true
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
        
        if SentrySDKOverrides.Feedback.injectScreenshot.boolValue {
            NotificationCenter.default.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        }
    }
    
    static let isoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter
    }()

    @IBAction func useAfterFree(_ sender: UIButton) {
//        imageView.image = UIImage(named: "")
        
        let sdkInfo = SentrySdkInfo.global()
        let releaseName = SentrySDK.options?.releaseName ?? "iOS-Swift"
        let traceId = SentrySDK.currentHub().scope.span?.traceContext?.traceId.sentryIdString ?? "00000000000000000000000000000000"
        
        let header = [
            "sdk": sdkInfo.serialize()
        ]
        let headerData = try! JSONSerialization.data(withJSONObject: header)
        
        let timestamp = Self.isoFormatter.string(from: Date())
        
        let logs = [
            "items": [
                [
                    "timestamp": timestamp,
                    "trace_id": traceId,
                    "level": "info",
                    "body": "foobar3",
                    "attributes": [
                        "foo": [
                            "value": "bar3",
                            "type": "string"
                        ],
                        "sentry.sdk.name":
                            [
                            "value": "sentry.cocoa",
                            "type": "string"
                            ],
                        "sentry.sdk.version":
                                [
                            "value": "8.50.1",
                            "type": "string"
                                ],
                        "sentry.environment":
                                [
                            "value": "debug",
                            "type": "string"
                                ],
                        "sentry.release":
                                [
                            "value": releaseName,
                            "type": "string"
                                ]
                    ],
                    "severity_number": 9
                ]
            ]
        ]
        let logsData = try! JSONSerialization.data(withJSONObject: logs)
        
        let itemHeader: [String: Any] = [
            "length": logsData.count,
            "type": "log",
            "item_count": 1,
            "content_type": "application/vnd.sentry.items.log+json"
        ]
        let itemHeaderData = try! JSONSerialization.data(withJSONObject: itemHeader)
        
        var itemData = Data()
        itemData.append(headerData)
        itemData.append(Data("\n".utf8))
        
        itemData.append(itemHeaderData)
        itemData.append(Data("\n".utf8))
        
        itemData.append(logsData)
        
        guard let envelope = PrivateSentrySDKOnly.envelope(with: itemData) else {
            print("Cannot parse the envelope data")
            return
        }
        SentrySDK.capture(envelope)
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

    @IBAction func throwFatalDuplicateKeyError(_ sender: Any) {
        // Triggers: Fatal error: Duplicate keys of type 'Something' were found in a Dictionary.
        var dict = [HashableViolation(): "value"]

        // Add plenty of items to the dictionary so it uses both == and hash methods, which will cause the crash.
        for i in 0..<1_000_000 {
            dict[HashableViolation()] = "value \(i)"
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
