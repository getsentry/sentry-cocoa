import SentrySampleShared
import UIKit

#if canImport(RoomPlan)
import RoomPlan
#endif

#if canImport(FoundationModels)
import FoundationModels
#endif

// Repro for GH-8152: with `@available`-gated UIViewController subclasses compiled in, eager
// swizzling realizes them at launch and crashes the app on an OS below the gate. Deferred
// first-instantiation swizzling avoids this because the class is never instantiated below its
// gate. These run through the real swizzle path (no `swizzleClassNameExcludes` workaround);
// verified on the iOS 16.4 simulator. (GH-8152 / GH-8548)

/// Host screen for the fixtures. Opening it is not what triggers the crash.
final class SubClassFinderRegressionViewController: UIViewController {

    static let accessibilityIdentifier = "subClassFinderRegressionScreen"

    private lazy var explanationLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = """
        Three @available-gated UIViewController subclasses are compiled into this app.
        On an OS below their gate, the SDK crashes the app during launch. (GH-8152)
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

        referenceGatedFixturesToPreventDeadStripping()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
    }

    /// Nothing else references the fixtures, so without this the linker strips them.
    private func referenceGatedFixturesToPreventDeadStripping() {
        if #available(iOS 17.0, *) {
            _ = GatedIOS17ViewController.self
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            _ = GatedIOS26OnlyViewController.self
        }
        #endif
        // `obsoleted: 26.0` makes the class referenceable only below iOS 26.
        if #unavailable(iOS 26.0) {
            _ = GatedObsoletedOnIOS26ViewController.self
        }
    }
}

// MARK: - Gated fixtures
//
// Never instantiated. Being compiled into the app is what matters.

/// The reported shape: gated on iOS 17, holds an iOS-17-only type. Crashes on iOS 16.4.
#if canImport(RoomPlan)
@available(iOS 17.0, *)
final class GatedIOS17ViewController: UIViewController {
    private var finalResults: CapturedStructure?
}
#else
// No RoomPlan in this SDK; keep a gated subclass without the gated property.
@available(iOS 17.0, *)
final class GatedIOS17ViewController: UIViewController {}
#endif

/// Same shape one OS version out, so the fixture keeps working once iOS 17 is the floor. Behind
/// `canImport` so the sample still compiles with a pre-iOS-26 SDK.
#if canImport(FoundationModels)
@available(iOS 26.0, *)
final class GatedIOS26OnlyViewController: UIViewController {
    private var session: LanguageModelSession?
}
#endif

/// Control: gated, but holds no gated type.
@available(iOS, obsoleted: 26.0)
final class GatedObsoletedOnIOS26ViewController: UIViewController {}
