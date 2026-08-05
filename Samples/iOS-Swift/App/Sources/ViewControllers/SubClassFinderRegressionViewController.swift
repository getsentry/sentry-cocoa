import SentrySampleShared
import UIKit

#if canImport(RoomPlan)
import RoomPlan
#endif

#if canImport(FoundationModels)
import FoundationModels
#endif

// The gated `Gated*ViewController` subclasses below are compiled into the app. The SDK's eager
// UIViewController swizzling realizes every subclass in the app image at start, and realizing a
// gated class that references a newer-framework type crashes on OS versions below its gate.
//
// `AppDelegate` therefore excludes these three by name via `swizzleClassNameExcludes`, the only
// workaround available today. Without it the sample crashes on start on the iOS 16.4 simulator —
// that is the bug these fixtures exist to hold onto. (GH-8152 / GH-8548)
//
// CI does not exercise the crash: the iOS-Swift UI tests run on iOS 17.5 / 18 / 26, all at or above
// the gates below. Verification is manual, on an iOS 16.4 simulator.

/// Host screen for the regression fixtures. It doesn't need to be opened — the fixtures just need to
/// be compiled in; opening it only makes the test tappable in the UI.
final class SubClassFinderRegressionViewController: UIViewController {

    static let accessibilityIdentifier = "subClassFinderRegressionScreen"

    private lazy var explanationLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = """
        Three @available-gated UIViewController subclasses are compiled into this app.
        If eager swizzling realizes them below their gate, the app crashes on launch.
        """
        label.accessibilityIdentifier = SubClassFinderRegressionViewController.accessibilityIdentifier
        return label.forAutoLayout()
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "SubClassFinder #8152"

        view.addSubview(explanationLabel)
        NSLayoutConstraint.activate([
            explanationLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            explanationLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            explanationLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        // Reference the metatypes so the linker can't dead-strip the fixtures. Touching a metatype
        // does not realize the class, so this is safe on any OS version.
        referenceGatedFixturesToPreventDeadStripping()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
    }

    private func referenceGatedFixturesToPreventDeadStripping() {
        if #available(iOS 17.0, *) {
            _ = GatedIOS17ViewController.self
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            _ = GatedIOS26OnlyViewController.self
        }
        #endif
        // `obsoleted: 26.0` means it can only be referenced below iOS 26.
        if #unavailable(iOS 26.0) {
            _ = GatedObsoletedOnIOS26ViewController.self
        }
    }
}

// MARK: - Gated fixtures (never instantiated; presence in the binary is the point)

/// Case 1: gated on iOS 17, holds `RoomPlan.CapturedStructure`. Swizzling realizes it and crashes
/// below iOS 17.
#if canImport(RoomPlan)
@available(iOS 17.0, *)
final class GatedIOS17ViewController: UIViewController {
    private var finalResults: CapturedStructure?
}
#else
// RoomPlan unavailable in this SDK; keep an iOS-17-gated subclass to walk.
@available(iOS 17.0, *)
final class GatedIOS17ViewController: UIViewController {}
#endif

/// Case 2: same shape as Case 1, gated at iOS 26 and holding `FoundationModels.LanguageModelSession`.
/// Behind `canImport` so the sample still builds against a pre-iOS-26 SDK.
#if canImport(FoundationModels)
@available(iOS 26.0, *)
final class GatedIOS26OnlyViewController: UIViewController {
    private var session: LanguageModelSession?
}
#endif

/// Case 3: `obsoleted: 26.0`, no newer-framework symbol — control case for the `@available` shape.
@available(iOS, obsoleted: 26.0)
final class GatedObsoletedOnIOS26ViewController: UIViewController {}
