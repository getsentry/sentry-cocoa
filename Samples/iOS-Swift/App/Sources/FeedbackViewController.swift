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

    @IBAction private func presentFromViewController(_: UIButton) {
        SentrySDK.feedback.presentForm(from: self)
    }

    @IBAction private func presentFromWindowScene(_: UIButton) {
        guard let windowScene = view.window?.windowScene else { return }
        SentrySDK.feedback.presentForm(in: windowScene)
    }

    @IBAction private func presentConvenience(_: UIButton) {
        SentrySDK.feedback.presentForm()
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
