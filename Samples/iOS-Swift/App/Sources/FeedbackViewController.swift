import Sentry
import UIKit

final class FeedbackViewController: UIViewController {
    @IBOutlet private weak var toggleWidgetButton: UIButton?

    private var isFeedbackWidgetVisible = true

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Feedback"
        view.backgroundColor = .systemBackground
        updateToggleWidgetButtonTitle()
    }

    @IBAction private func presentController(_: UIButton) {
        let config = SentrySDK.FeedbackFormConfig()
        config.formTitle = "Report a Problem"
        let form = SentrySDK.FeedbackForm(config: config)
        present(form, animated: true)
    }

    @IBAction private func presentFallback(_: UIButton) {
        SentrySDK.feedback.show(config: SentrySDK.FeedbackFormConfig())
    }

    @IBAction private func toggleWidget(_: UIButton) {
        if isFeedbackWidgetVisible {
            SentrySDK.feedback.hideWidget()
        } else {
            SentrySDK.feedback.showWidget()
        }
        isFeedbackWidgetVisible.toggle()
        updateToggleWidgetButtonTitle()
    }

    private func updateToggleWidgetButtonTitle() {
        setTitle(isFeedbackWidgetVisible ? "Hide Widget" : "Show Widget", for: toggleWidgetButton)
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
