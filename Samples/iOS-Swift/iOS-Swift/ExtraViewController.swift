import Foundation
import Sentry
import UIKit

class ExtraViewController: UIViewController {

    @IBOutlet weak var framesLabel: UILabel!
    @IBOutlet weak var breadcrumbLabel: UILabel!
    @IBOutlet weak var uiTestNameLabel: UILabel!
    @IBOutlet weak var anrFullyBlockingButton: UIButton!
    @IBOutlet weak var anrFillingRunLoopButton: UIButton!
    @IBOutlet weak var dataMarshalingField: UITextField!
    @IBOutlet weak var dataMarshalingStatusLabel: UILabel!
    @IBOutlet weak var dataMarshalingErrorLabel: UILabel!
    
    @IBOutlet weak var dsnView: UIView!
    private let dispatchQueue = DispatchQueue(label: "ExtraViewControllers", attributes: .concurrent)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let uiTestName = ProcessInfo.processInfo.environment["--io.sentry.ui-test.test-name"] {
            uiTestNameLabel.text = uiTestName
            uiTestNameLabel.isHidden = false
        }
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.framesLabel?.text = "Frames Total:\(PrivateSentrySDKOnly.currentScreenFrames.total) Slow:\(PrivateSentrySDKOnly.currentScreenFrames.slow) Frozen:\(PrivateSentrySDKOnly.currentScreenFrames.frozen)"
        }

        addDSNDisplay(self, vcview: dsnView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        SentrySDK.configureScope { (scope) in
            let dict = scope.serialize()

            guard
                let crumbs = dict["breadcrumbs"] as? [[String: Any]],
                let breadcrumb = crumbs.last,
                let data = breadcrumb["data"] as? [String: String]
            else {
                return
            }

            self.breadcrumbLabel?.text = "{ category: \(breadcrumb["category"] ?? "nil"), parentViewController: \(data["parentViewController"] ?? "nil"), beingPresented: \(data["beingPresented"] ?? "nil"), window_isKeyWindow: \(data["window_isKeyWindow"] ?? "nil"), is_window_rootViewController: \(data["is_window_rootViewController"] ?? "nil") }"

        }
        
        SentrySDK.reportFullyDisplayed()
    }
    
    @IBAction func anrDeadlock(_ sender: UIButton) {
        highlightButton(sender)
        let queue1 = DispatchQueue(label: "queue1")
        let queue2 = DispatchQueue(label: "queue2")

        queue1.async {
            queue2.sync {
                DispatchQueue.main.sync {
                    queue1.sync {
                        // Queue 2 waits for us, so DEADLOCK on the main thread.
                    }
                }
            }
        }
    }

    @IBAction func anrFullyBlocking(_ sender: UIButton) {
        highlightButton(sender)
        let buttonTitle = self.anrFullyBlockingButton.currentTitle
        var i = 0

        for _ in 0...5_000_000 {
            i += Int.random(in: 0...10)
            i -= 1

            self.anrFullyBlockingButton.setTitle("\(i)", for: .normal)
        }

        self.anrFullyBlockingButton.setTitle(buttonTitle, for: .normal)
    }

    @IBAction func anrFillingRunLoop(_ sender: UIButton) {
        highlightButton(sender)
        triggerNonFullyBlockingAppHang()
    }

    @IBAction func getPasteBoardString(_ sender: Any) {
        SentrySDK.pauseAppHangTracking()
        
        // Getting the pasteboard string asks for permission
        // and the SDK would detect an ANR if we don't pause it.
        // Make sure to copy something into the pasteboard, cause
        // iOS only opens the system permission dialog if you do.
        
        if let clipboard = UIPasteboard.general.string {
            SentrySDK.capture(message: clipboard)
        }
        
        SentrySDK.resumeAppHangTracking()
    }
    
    @IBAction func start100Threads(_ sender: UIButton) {
        highlightButton(sender)
        for _ in 0..<100 {
            Thread.detachNewThread {
                Thread.sleep(forTimeInterval: 10)
            }
        }
    }

    @IBAction func highCPULoad(_ sender: UIButton) {
        highlightButton(sender)
        dispatchQueue.async {
            while true {
                _ = self.calcPi()
            }
        }
    }

    @IBAction func addBreadcrumb(_ sender: UIButton) {
        highlightButton(sender)
        let crumb = Breadcrumb(level: SentryLevel.info, category: "Debug")
        crumb.message = "tapped addBreadcrumb"
        crumb.type = "user"
        SentrySDK.addBreadcrumb(crumb)
    }

    @IBAction func captureMessage(_ sender: UIButton) {
        highlightButton(sender)
        let eventId = SentrySDK.capture(message: "Yeah captured a message")
        // Returns eventId in case of successfull processed event
        // otherwise nil
        print("\(String(describing: eventId))")
    }
    
    @IBAction func openWeb(_ sender: UIButton) {
        navigationController?.pushViewController(WebViewController(), animated: true)
    }

    @IBAction func captureUserFeedbackV2(_ sender: UIButton) {
        highlightButton(sender)
        var attachments: [Data]?
        if let url = Bundle.main.url(forResource: "screenshot", withExtension: "png"), let data = try? Data(contentsOf: url) {
            attachments = [data]
        }
        let errorEventID = SentrySDK.capture(error: NSError(domain: "test-error.user-feedback.iOS-Swift", code: 1))
        let feedback = SentryFeedback(message: "It broke again on iOS-Swift. I don't know why, but this happens.", name: "John Me", email: "john@me.com", source: .custom, associatedEventId: errorEventID, attachments: attachments)
        SentrySDK.capture(feedback: feedback)
    }
    
    @IBAction func captureUserFeedback(_ sender: UIButton) {
        highlightButton(sender)
        let error = NSError(domain: "UserFeedbackErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey: "This never happens."])

        let eventId = SentrySDK.capture(error: error) { scope in
            scope.setLevel(.fatal)
        }

        let userFeedback = UserFeedback(eventId: eventId)
        userFeedback.comments = "It broke on iOS-Swift. I don't know why, but this happens."
        userFeedback.email = "john@me.com"
        userFeedback.name = "John Me"
        SentrySDK.capture(userFeedback: userFeedback)
    }

    @IBAction func permissions(_ sender: UIButton) {
        highlightButton(sender)
        let controller = PermissionsViewController()
        controller.title = "Permissions"
        navigationController?.pushViewController(controller, animated: true)
    }

    @IBAction func flush(_ sender: UIButton) {
        highlightButton(sender)
        SentrySDK.flush(timeout: 5)
    }
    
    @IBAction func showTopVCInspector(_ sender: UIButton) {
        TopViewControllerInspector.show()
    }

    @IBAction func close(_ sender: UIButton) {
        highlightButton(sender)
        SentrySDK.close()
    }

    @IBAction func startSDK(_ sender: UIButton) {
        highlightButton(sender)
        SentrySDKWrapper.shared.startSentry()
    }

    @IBAction func causeFrozenFrames(_ sender: Any) {
        var a = String()
        for i in 0..<100_000_000 {
            a.append(String(i))
        }
    }

    private func calcPi() -> Double {
        var denominator = 1.0
        var pi = 0.0

        for i in 0..<10_000_000 {
            if i % 2 == 0 {
                pi += 4 / denominator
            } else {
                pi -= 4 / denominator
            }

            denominator += 2
        }

        return pi
    }
    
    enum EnvelopeContent {
        /// String contents are base64 encoded image data
        case image(String)
        
        case rawText(String)
        case json([String: Any])
        
        /// String contents are base64 encoded image data
        case feedbackAttachment(String)
    }
    
    func displayError(message: String) {
        dataMarshalingStatusLabel.isHidden = false
        dataMarshalingStatusLabel.text = "❌"
        dataMarshalingErrorLabel.isHidden = false
        dataMarshalingErrorLabel.text = message
        print("[iOS-Swift] \(message)")
    }
    
    @IBAction func getLatestEnvelope(_ sender: Any) {
        guard let latestEnvelopePath = latestEnvelopePath() else { return }
        guard let base64String = base64EncodedStructuredUITestData(envelopePath: latestEnvelopePath) else { return }
        displayStringForUITest(string: base64String)
    }
    
    @IBAction func getApplicationSupportPath(_ sender: Any) {
        guard let appSupportDirectory = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first else {
            print("[iOS-Swift] Couldn't retrieve path to application support directory.")
            return
        }
        displayStringForUITest(string: appSupportDirectory)
    }
    
    @IBAction func showMaskingPreview(_ sender: Any) {
        SentrySDK.replay.showMaskPreview(0.5)
    }
    
    func displayStringForUITest(string: String) {
        dataMarshalingField.text = string
        dataMarshalingField.isHidden = false
        dataMarshalingStatusLabel.isHidden = false
        dataMarshalingStatusLabel.text = "✅"
        dataMarshalingErrorLabel.isHidden = true
    }
    
    func latestEnvelopePath() -> String? {
        guard let cachesDirectory = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first else {
            displayError(message: "No user caches directory found on device.")
            return nil
        }
        let fm = FileManager.default
        guard let dsnHash = try? SentryDsn(string: SentrySDKWrapper.defaultDSN).getHash() else {
            displayError(message: "Couldn't compute DSN hash.")
            return nil
        }
        let dir = "\(cachesDirectory)/io.sentry/\(dsnHash)/envelopes"
        guard let contents = try? fm.contentsOfDirectory(atPath: dir) else {
            displayError(message: "\(dir) has no contents.")
            return nil
        }
        guard let latest = contents.compactMap({ path -> (String, Date)? in
            guard let attr = try? fm.attributesOfItem(atPath: "\(dir)/\(path)"), let date = attr[FileAttributeKey.modificationDate] as? Date else {
                return nil
            }
            return (path, date)
        }).sorted(by: { a, b in
            return a.1.compare(b.1) == .orderedAscending
        }).last else {
            displayError(message: "Could not find any envelopes in \(dir).")
            return nil
        }
        return "\(dir)/\(latest.0)"
    }
    
    func base64EncodedStructuredUITestData(envelopePath: String) -> String? {
        guard let envelopeFileContents = try? String(contentsOfFile: envelopePath) else {
            displayError(message: "\(envelopePath) had no contents.")
            return nil
        }
        var waitingForFeedbackAttachment = false
        let parsedEnvelopeContents = envelopeFileContents.split(separator: "\n").map { line in
            if let _ = Data(base64Encoded: String(line), options: []) {
                guard !waitingForFeedbackAttachment else {
                    waitingForFeedbackAttachment = false
                    return EnvelopeContent.feedbackAttachment(String(line))
                }
                return EnvelopeContent.image(String(line))
            } else if let data = line.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let type = json["attachment_type"] as? String, type == "event.attachment" {
                    waitingForFeedbackAttachment = true
                }
                return EnvelopeContent.json(json)
            } else {
                return EnvelopeContent.rawText(String(line))
            }
        }
        let contentsForUITest = parsedEnvelopeContents.reduce(into: [String: Any]()) { result, item in
            switch item {
            case let .rawText(text): result["text"] = text
            case let .image(base64Data): result["scope_images"] = (result["scope_images"] as? [String]) ?? [] + [base64Data]
            case let .feedbackAttachment(base64Data): result["feedback_attachments"] = (result["feedback_attachments"] as? [String]) ?? [] + [base64Data]
            case let .json(json): insertValues(from: json, into: &result)
            }
        }
        guard let data = try? JSONSerialization.data(withJSONObject: contentsForUITest) else {
            displayError(message: "Couldn't serialize marshaling dictionary.")
            return nil
        }
        
        return data.base64EncodedString()
    }
    
    func insertValues(from json: [String: Any], into result: inout [String: Any]) {
        if let eventContexts = json["contexts"] as? [String: Any] {
            result["event_type"] = json["type"]
            if let feedback = eventContexts["feedback"] as? [String: Any] {
                result["message"] = feedback["message"]
                result["contact_email"] = feedback["contact_email"]
                result["source"] = feedback["source"]
                result["name"] = feedback["name"]
            }
        } else if let itemHeaderEventId = json["event_id"] {
            result["event_id"] = itemHeaderEventId
        } else if let _ = json["length"], let type = json["type"] as? String, type == "feedback" {
            result["item_header_type"] = json["type"]
        }
    }
}
