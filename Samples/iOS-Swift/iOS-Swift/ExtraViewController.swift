import Foundation
import Sentry
import UIKit

class ExtraViewController: UIViewController {

    @IBOutlet weak var dsnTextField: UITextField!
    @IBOutlet weak var framesLabel: UILabel!
    @IBOutlet weak var breadcrumbLabel: UILabel!
    @IBOutlet weak var uiTestNameLabel: UILabel!
    @IBOutlet weak var anrFullyBlockingButton: UIButton!
    @IBOutlet weak var anrFillingRunLoopButton: UIButton!

    private let dispatchQueue = DispatchQueue(label: "ExtraViewControllers", attributes: .concurrent)

    override func viewDidLoad() {
        super.viewDidLoad()

        dispatchQueue.async {
            let dsn = DSNStorage.shared.getDSN()

            DispatchQueue.main.async {
                self.dsnTextField.text = dsn
                self.dsnTextField.backgroundColor = UIColor.systemGreen
            }
        }

        if let uiTestName = ProcessInfo.processInfo.environment["io.sentry.ui-test.test-name"] {
            uiTestNameLabel.text = uiTestName
        }

        SentrySDK.reportFullyDisplayed()
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            self.framesLabel?.text = "Frames Total:\(PrivateSentrySDKOnly.currentScreenFrames.total) Slow:\(PrivateSentrySDKOnly.currentScreenFrames.slow) Frozen:\(PrivateSentrySDKOnly.currentScreenFrames.frozen)"
        }

        SentrySDK.reportFullyDisplayed()
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
    }

    @IBAction func dsnChanged(_ sender: UITextField) {
        let options = Options()
        options.dsn = sender.text

        if let dsn = options.dsn {
            sender.backgroundColor = UIColor.systemGreen

            dispatchQueue.async {
                DSNStorage.shared.saveDSN(dsn: dsn)
            }
        } else {
            sender.backgroundColor = UIColor.systemRed

            dispatchQueue.async {
                DSNStorage.shared.deleteDSN()
            }
        }
    }

    @IBAction func resetDSN(_ sender: UIButton) {
        highlightButton(sender)
        self.dsnTextField.text = AppDelegate.defaultDSN
        self.dsnTextField.backgroundColor = UIColor.systemGreen

        dispatchQueue.async {
            DSNStorage.shared.saveDSN(dsn: AppDelegate.defaultDSN)
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
        let buttonTitle = self.anrFillingRunLoopButton.currentTitle
        var i = 0

        func sleep(timeout: Double) {
            let group = DispatchGroup()
            group.enter()
            let queue = DispatchQueue(label: "delay", qos: .background, attributes: [])

            queue.asyncAfter(deadline: .now() + timeout) {
                group.leave()
            }

            group.wait()
        }

        dispatchQueue.async {
            for _ in 0...30 {
                i += Int.random(in: 0...10)
                i -= 1

                DispatchQueue.main.async {
                    sleep(timeout: 0.1)
                    self.anrFillingRunLoopButton.setTitle("Title \(i)", for: .normal)
                }
            }

            DispatchQueue.main.sync {
                self.anrFillingRunLoopButton.setTitle(buttonTitle, for: .normal)
            }
        }
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
        AppDelegate.startSentry()
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
}
