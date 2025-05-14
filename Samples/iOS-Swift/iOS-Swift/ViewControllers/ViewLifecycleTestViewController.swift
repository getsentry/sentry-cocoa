import UIKit

// This is a test view controller to test the swizzling of view lifecycle methods.
//
// See ``SentryUIViewControllerSwizzling.m`` for the list of swizzled methods.
//
// We need to assert that the swizzling is enabled or disabled in the right places.
// This is important because we want to ensure in regression tests, that swizzling does not cause SDK crashes.
class ViewLifecycleTestViewController: UIViewController {
    @IBOutlet weak var dismissWithLoadViewButton: UIButton!
    @IBOutlet weak var dismissWithViewDidLoadButton: UIButton!
    @IBOutlet weak var dismissWithViewWillAppearButton: UIButton!
    @IBOutlet weak var dismissWithViewDidAppearButton: UIButton!
    @IBOutlet weak var dismissWithViewWillDisappearButton: UIButton!
    @IBOutlet weak var dismissWithViewDidDisappearButton: UIButton!
    @IBOutlet weak var dismissWithViewWillLayoutSubviewsButton: UIButton!
    @IBOutlet weak var dismissWithViewDidLayoutSubviewsButton: UIButton!

    // swiftlint:disable:next prohibited_super_call
    override func loadView() {
        super.loadView()
    
        print("This statement is printed in loadView")
        assertSwizzlingIsEnabled()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("This statement is printed in viewDidLoad")

        assertSwizzlingIsEnabled()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("This statement is printed in viewWillAppear")

        assertSwizzlingIsEnabled()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("This statement is printed in viewDidAppear")

        assertSwizzlingIsEnabled()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("This statement is printed in viewWillDisappear")

        assertSwizzlingIsEnabled()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("This statement is printed in viewDidDisappear")

        // Note: At this point we do NOT have swizzling for viewDidDisappear.
        // We assert this behaviour to have tests fail in case it's changed in the future.
        assertSwizzlingIsDisabled()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        print("This statement is printed in viewWillLayoutSubviews")

        assertSwizzlingIsEnabled()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("This statement is printed in viewDidLayoutSubviews")

        assertSwizzlingIsEnabled()
    }

    @IBAction func dismissButtonTouchUpAction(_ sender: UIButton) {
        // This is the place where we call view lifecycle methods after the view is dismissed.
        // This is invalid behaviour, but the SDK should not crash.
        // See also https://developer.apple.com/documentation/uikit/uiviewcontroller/beginappearancetransition(_:animated:)#Discussion for related information.
        DispatchQueue.global(qos: .default).async {
            DispatchQueue.main.async {
                self.dismiss(animated: false) {
                    DispatchQueue.main.async {
                        self.triggerViewLifecycleMethod(sender)
                    }
                }
            }
        }
    }

    func triggerViewLifecycleMethod(_ sender: UIButton) {
        if sender === self.dismissWithLoadViewButton {
            self.loadView()
        } else if sender === self.dismissWithViewDidLoadButton {
            self.viewDidLoad()
        } else if sender === self.dismissWithViewWillAppearButton {
            self.viewWillAppear(false)
        } else if sender === self.dismissWithViewDidAppearButton {
            self.viewDidAppear(false)
        } else if sender === self.dismissWithViewWillDisappearButton {
            self.viewWillDisappear(false)
        } else if sender === self.dismissWithViewDidDisappearButton {
            self.viewDidDisappear(false)
        } else if sender === self.dismissWithViewWillLayoutSubviewsButton {
            self.viewWillLayoutSubviews()
        } else if sender === self.dismissWithViewDidLayoutSubviewsButton {
            self.viewDidLayoutSubviews()
        }
    }

    fileprivate func assertSwizzlingIsEnabled() {
        let stacktraceContainsUIViewControllerSwizzling = Thread.callStackSymbols.contains { frame in
            frame.contains("SentryUIViewControllerSwizzling swizzle")
        }
        assert(stacktraceContainsUIViewControllerSwizzling, "view life cycle method should be swizzled")
    }

    fileprivate func assertSwizzlingIsDisabled() {
        let stacktraceContainsUIViewControllerSwizzling = Thread.callStackSymbols.contains { frame in
            frame.contains("SentryUIViewControllerSwizzling swizzle")
        }
        assert(!stacktraceContainsUIViewControllerSwizzling, "view life cycle method should not be swizzled")
    }
}
