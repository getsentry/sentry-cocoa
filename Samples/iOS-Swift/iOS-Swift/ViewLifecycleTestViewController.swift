import UIKit

class ViewLifecycleTestViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        print("This statement is printed in viewDidLoad")

        // We need to ensure that view controller swizzling is active.
        // Otherwise this test is rather useless.
        let stacktraceContainsUIViewControllerSwizzling = Thread.callStackSymbols.contains { frame in
            frame.contains("SentryUIViewControllerSwizzling swizzleViewDidLoad")
        }
        assert(stacktraceContainsUIViewControllerSwizzling, "viewDidLoad should be swizzled")
    }

    @IBAction func dismissButtonTouchUpAction(_ sender: UIButton) {
        // This is the place where we call view lifecycle methods after the view is dismissed.
        // This is invalid behaviour, but the SDK should not crash.
        DispatchQueue.global(qos: .default).async {
            DispatchQueue.main.async {
                self.dismiss(animated: false) {
                    DispatchQueue.main.async {
                        self.viewDidLoad()
                    }
                }
            }
        }
    }

}
