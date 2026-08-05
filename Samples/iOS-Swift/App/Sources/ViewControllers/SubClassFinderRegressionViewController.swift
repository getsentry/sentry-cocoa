import SentrySampleShared
import UIKit

#if canImport(RoomPlan)
import RoomPlan
#endif

#if canImport(FoundationModels)
import FoundationModels
#endif

// The gated `Gated*ViewController` subclasses below are compiled into the app so the GH-8152 crash
// shape lives in a runnable target.
//
// Mechanism: at start, `SentrySubClassFinder` walks *every* class name in the app image and calls
// `NSClassFromString` on each one to test whether it descends from `UIViewController`. That call
// realizes the class, which runs its Swift metadata accessor, which in turn resolves the types of
// its stored properties. If a stored property's type ships in a framework newer than the running
// OS, that resolution segfaults — below the class's own `@available` gate, where the compiler
// assumed the type would never be looked up.
//
// `AppDelegate` therefore excludes these three by name via `swizzleClassNameExcludes` (matched
// before `NSClassFromString`, so the class is never realized), the only workaround available today.
// Without it the sample dies during launch on the iOS 16.4 simulator, on the
// `io.sentry.ui-view-controller-swizzling` queue — that is the bug these fixtures exist to hold
// onto. (GH-8152, fix tracked in GH-8548)
//
// CI does not exercise the crash: the iOS-Swift UI tests run on iOS 17.5 / 18 / 26, all at or above
// the gates below. Reproducing it means removing the exclusions and launching on an iOS 16.4
// simulator by hand.

/// Host screen for the regression fixtures. Opening it is not what triggers the bug — the fixtures
/// only need to be present in the binary, since the finder walks the image at start. The screen
/// exists so a UI test has something to assert on and so the fixtures are discoverable by a reader.
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

        // Keep the fixtures in the binary; nothing else references them, so they are dead-strip
        // candidates. Only reached when the screen is opened, which the UI test does on CI.
        referenceGatedFixturesToPreventDeadStripping()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
    }

    /// Each `_ = X.self` calls the class's metadata accessor, i.e. the same realization the finder
    /// triggers. The availability checks are what keep that safe here: each metatype is only touched
    /// on an OS at or above its own gate.
    private func referenceGatedFixturesToPreventDeadStripping() {
        if #available(iOS 17.0, *) {
            _ = GatedIOS17ViewController.self
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            _ = GatedIOS26OnlyViewController.self
        }
        #endif
        // Inverted check: `obsoleted: 26.0` makes the class referenceable only *below* iOS 26.
        if #unavailable(iOS 26.0) {
            _ = GatedObsoletedOnIOS26ViewController.self
        }
    }
}

// MARK: - Gated fixtures
//
// None of these are ever instantiated. Their presence in the app image is the whole fixture: the
// finder enumerates class *names*, so a class only has to be compiled in to be realized.

/// Case 1: gated on iOS 17, stored property typed `RoomPlan.CapturedStructure` (iOS 17+). This is
/// the exact shape reported in GH-8152 and the one confirmed to crash: on iOS 16.4, realizing it
/// traps inside the `CapturedStructure` metadata accessor.
#if canImport(RoomPlan)
@available(iOS 17.0, *)
final class GatedIOS17ViewController: UIViewController {
    private var finalResults: CapturedStructure?
}
#else
// RoomPlan missing from this SDK (e.g. tvOS-style toolchains). Keep an iOS-17-gated subclass so the
// finder still has one to walk — without the newer-framework property it cannot reproduce the
// crash, only the enumeration path.
@available(iOS 17.0, *)
final class GatedIOS17ViewController: UIViewController {}
#endif

/// Case 2: same shape one OS version further out — gated on iOS 26, stored property typed
/// `FoundationModels.LanguageModelSession`. Catches the same bug on a future runner, where Case 1's
/// gate has long been cleared. Behind `canImport` so the sample still compiles with a pre-iOS-26 SDK.
#if canImport(FoundationModels)
@available(iOS 26.0, *)
final class GatedIOS26OnlyViewController: UIViewController {
    private var session: LanguageModelSession?
}
#endif

/// Case 3: control. `@available` gate but no newer-framework type, so realizing it is harmless. It
/// isolates the trigger: if only Cases 1 and 2 crash, the gate alone is not the cause — the
/// unresolvable property type is.
@available(iOS, obsoleted: 26.0)
final class GatedObsoletedOnIOS26ViewController: UIViewController {}
