import SentrySampleShared
import UIKit

// Manual performance reproducer for GH-9536: add many child view controllers in one run-loop turn
// to investigate UIViewController tracing overhead.
//
// UIKit insertion and layout performance depends heavily on the machine and simulator. The elapsed
// time also includes display-link scheduling delay, so a fixed wall-clock threshold cannot reliably
// isolate SDK regressions across CI machines. Use this screen for controlled comparisons instead.
//
// Ported from https://github.com/ig-sentry/sentry-cocoa-vc-tracing-hang. The reporter saw a 6.5–8 s
// app hang with 2,000 children on an iPhone SE (2nd gen), versus ~0.3 s without Sentry.
//
// Compare tracing with the child class excluded through `swizzleClassNameExcludes`.

/// The child added in bulk. Kept top-level with a stable name so `swizzleClassNameExcludes` can
/// match it without also matching the parent screen.
final class ManyChildViewControllersChildViewController: UIViewController {
    override func loadView() {
        view = UIView()
        view.backgroundColor = .systemBlue
    }
}

final class ManyChildViewControllersViewController: UIViewController {

    private static let childCountEnvironmentKey = "--io.sentry.ui-test.many-child-view-controllers-count"
    private static let blockedSecondsAccessibilityIdentifier = "manyChildViewControllersBlockedSeconds"

    private let childCount = ProcessInfo.processInfo.environment[
        ManyChildViewControllersViewController.childCountEnvironmentKey
    ].flatMap(Int.init) ?? 2_000

    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .bold)
        label.text = "Tap Add to add \(childCount) child view controllers."
        return label.forAutoLayout()
    }()

    /// Elapsed seconds until the display-link callback after the last burst, or `pending` before
    /// the first burst. Includes insertion, layout, and display-link scheduling delay.
    private let blockedSecondsLabel: UILabel = {
        let label = UILabel()
        label.text = "pending"
        label.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        label.textAlignment = .center
        label.accessibilityIdentifier = ManyChildViewControllersViewController.blockedSecondsAccessibilityIdentifier
        return label.forAutoLayout()
    }()

    private let gridView = UIView().forAutoLayout()
    private var burstStart: CFTimeInterval = 0
    private var displayLink: CADisplayLink?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Many child VCs #9536"

        let addButton = UIBarButtonItem(title: "Add", style: .plain, target: self, action: #selector(addChildren))
        addButton.accessibilityIdentifier = "manyChildViewControllersAdd"
        navigationItem.rightBarButtonItem = addButton

        view.addSubview(statusLabel)
        view.addSubview(blockedSecondsLabel)
        view.addSubview(gridView)
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            blockedSecondsLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            blockedSecondsLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            blockedSecondsLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            gridView.topAnchor.constraint(equalTo: blockedSecondsLabel.bottomAnchor, constant: 16),
            gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gridView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    @objc private func addChildren() {
        burstStart = CACurrentMediaTime()
        for index in 0..<childCount {
            let child = ManyChildViewControllersChildViewController()
            addChild(child)
            gridView.addSubview(child.view)
            child.didMove(toParent: self)
            child.view.frame = CGRect(x: 4 + (index % 50) * 7, y: (index / 50) * 7, width: 5, height: 5)
        }
        // The swizzled appearance and layout callbacks for all children run here and in the
        // following layout pass.
        view.layoutIfNeeded()

        // Measure through the next display-link callback, including layout and scheduling delay.
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(firstFrameAfterBurst))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func firstFrameAfterBurst() {
        displayLink?.invalidate()
        displayLink = nil

        let blockedSeconds = CACurrentMediaTime() - burstStart
        let text = String(format: "%.2f", blockedSeconds)
        statusLabel.text = "Added \(childCount) children (\(children.count) total). Elapsed time to display-link callback:"
        blockedSecondsLabel.text = text
    }
}
