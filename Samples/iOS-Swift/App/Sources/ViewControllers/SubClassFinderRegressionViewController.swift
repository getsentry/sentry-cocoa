import SentrySampleShared
import UIKit

#if canImport(RoomPlan)
import RoomPlan
#endif

#if canImport(FoundationModels)
import FoundationModels
#endif

// Regression test for GH-8152: the gated `Gated*ViewController` subclasses below are compiled into
// the app so `SentrySubClassFinder` must enumerate them at launch without realizing them.
//
// Discovery is fixed, but *swizzling* a discovered gated subclass still realizes it and crashes on
// OS versions below its gate (residual GH-8152, tracked in GH-8548). The AppDelegate therefore adds
// the two crasher fixtures (Cases 1 and 2) to `options.swizzleClassNameExcludes` — the documented
// workaround. Removing those excludes re-arms the crash repro on the iOS 16.4 simulator, which is
// the acceptance gate for the deferred-swizzling follow-up (GH-8548).

/// Host screen for the regression fixtures. It doesn't need to be opened — the fixtures just need to
/// be compiled in; opening it only makes the test tappable in the UI.
final class SubClassFinderRegressionViewController: UIViewController {

    static let accessibilityIdentifier = "subClassFinderRegressionScreen"

    private lazy var explanationLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = """
        This screen only exists to reproduce #8152.

        Three @available-gated UIViewController subclasses are compiled into this app so the SDK's \
        SentrySubClassFinder must enumerate them at launch without realizing them. If that regresses, \
        the app crashes on launch.

        The two crasher fixtures are excluded from swizzling via swizzleClassNameExcludes in the \
        AppDelegate — the documented workaround for the residual swizzle-time crash (GH-8548).
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

/// Case 1: gated on iOS 17, holding `RoomPlan.CapturedStructure` — the exact GH-8152 crasher.
/// Swizzling this class realizes it and crashes below iOS 17; excluded via
/// `swizzleClassNameExcludes` in the AppDelegate (workaround for GH-8548).
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

/// Case 2: gated on iOS 26, holding `FoundationModels.LanguageModelSession`. Behind `canImport` so
/// the sample still builds with a pre-iOS-26 SDK, where the type doesn't exist. Same crasher shape
/// as Case 1 (gated at iOS 26); also excluded via `swizzleClassNameExcludes` in the AppDelegate.
#if canImport(FoundationModels)
@available(iOS 26.0, *)
final class GatedIOS26OnlyViewController: UIViewController {
    private var session: LanguageModelSession?
}
#endif

/// Case 3: `obsoleted: 26.0`. No newer-framework symbol, so not a crasher itself — the control for
/// the third `@available` shape.
@available(iOS, obsoleted: 26.0)
final class GatedObsoletedOnIOS26ViewController: UIViewController {}
