import UIKit

final class OS27PrewarmViewController: UIViewController {
    private let summaryLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        navigationItem.title = "xOS 27 Prewarm"

        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        titleLabel.text = "App launch probe"
        titleLabel.textAlignment = .center

        summaryLabel.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        summaryLabel.numberOfLines = 0
        summaryLabel.text = OS27PrewarmProbe.shared.summaryText
        summaryLabel.accessibilityIdentifier = "os27-prewarm-summary"

        let shareButton = UIButton(type: .system)
        shareButton.setTitle("Share current report", for: .normal)
        shareButton.addTarget(self, action: #selector(shareReport), for: .touchUpInside)

        let copyButton = UIButton(type: .system)
        copyButton.setTitle("Copy summary", for: .normal)
        copyButton.addTarget(self, action: #selector(copySummary), for: .touchUpInside)

        let instructionsLabel = UILabel()
        instructionsLabel.font = .preferredFont(forTextStyle: .footnote)
        instructionsLabel.numberOfLines = 0
        instructionsLabel.text = "Launch from the Home Screen without a debugger. Reports are also available in Files → On My iPhone → OS27-Prewarm."

        let stack = UIStackView(arrangedSubviews: [
            titleLabel,
            summaryLabel,
            shareButton,
            copyButton,
            instructionsLabel
        ])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        OS27PrewarmProbe.shared.record(
            name: "rootView.viewDidAppear",
            applicationState: UIApplication.shared.applicationState,
            details: ["animated": animated]
        )
        summaryLabel.text = OS27PrewarmProbe.shared.summaryText
    }

    @objc
    private func shareReport() {
        guard let reportURL = OS27PrewarmProbe.shared.currentReportURL() else { return }
        let activity = UIActivityViewController(activityItems: [reportURL], applicationActivities: nil)
        if let popover = activity.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
        }
        present(activity, animated: true)
    }

    @objc
    private func copySummary() {
        UIPasteboard.general.string = OS27PrewarmProbe.shared.summaryText
    }
}
