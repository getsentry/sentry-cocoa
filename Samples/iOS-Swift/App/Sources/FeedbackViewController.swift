import SentrySampleShared
import SentrySwift
import UIKit

final class FeedbackViewController: UIViewController {
    @IBOutlet private weak var toggleWidgetButton: UIButton?

    private var isFeedbackWidgetVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Feedback"
        view.backgroundColor = .systemBackground
        updateToggleWidgetButtonTitle()
    }

    @IBAction private func presentController(_: UIButton) {
        let form = SentrySDK.FeedbackForm { config in
            config.configureForm = { form in
                form.formTitle = "Report Feedback"
                form.submitButtonLabel = "Send Feedback"
                form.enableScreenshot = true
            }
            config.tags = ["presentation": "uikit-controller"]
        }
        present(form, animated: true)
    }

    @IBAction private func presentFallback(_: UIButton) {
        SentrySDK.feedback.show { config in
            config.tags = ["presentation": "convenience-api"]
        }
    }

    @IBAction private func enableFeedbackOnShake(_: UIButton) {
        SentrySDK.feedback.enableOnShake()
    }

    @IBAction private func disableFeedbackOnShake(_: UIButton) {
        SentrySDK.feedback.disableOnShake()
    }

    @IBAction private func toggleWidget(_: UIButton) {
        if isFeedbackWidgetVisible {
            SentrySampleFeedback.hideWidget()
        } else {
            SentrySampleFeedback.showWidget()
        }
        isFeedbackWidgetVisible.toggle()
        updateToggleWidgetButtonTitle()
    }

    private func updateToggleWidgetButtonTitle() {
        setTitle(isFeedbackWidgetVisible ? "Hide Widget (Deprecated)" : "Show Widget (Deprecated)", for: toggleWidgetButton)
    }

    private func setTitle(_ title: String, for button: UIButton?) {
        if var configuration = button?.configuration {
            configuration.title = title
            button?.configuration = configuration
        } else {
            button?.setTitle(title, for: .normal)
        }
    }
}
