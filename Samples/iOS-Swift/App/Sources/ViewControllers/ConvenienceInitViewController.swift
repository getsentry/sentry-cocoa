import UIKit

// Regression fixture for GH-1355 / GH-1361, revisited by GH-8548.
//
// The SDK removed UIViewController init swizzling in GH-1361 because the old approach crashed apps
// that used a custom convenience/designated initializer on iOS 15 with
// `NSInternalInconsistencyException: UIViewController is missing its initial trait collection
// populated during initialization`. The root cause: the old funnel mutated the subclass's method
// list *from inside* the initializer (before calling the original init).
//
// Deferred first-instantiation swizzling (GH-8548) re-introduces base-init swizzling, so this exact
// shape must stay crash-free. This is brustolin's minimal repro from the GH-1355 discussion: a
// `UITableViewController` subclass with a convenience initializer that delegates to a custom
// designated initializer (`super.init(style:)`), deliberately WITHOUT `@objc` (adding `@objc` was the
// original workaround). Instantiating it via its convenience init exercises the init path the SDK now
// swizzles.
//
// Note: the original GH-1355 crash was reported only on iOS 15.0 via TestFlight/Release builds on
// devices and was flaky (an Apple UIKit bug that was never root-caused; adding `@objc` to the init
// worked around it). It could NOT be reproduced on the iOS 15.5 simulator here, even with the old
// crash-inducing swizzle ordering (mutating the class before the original init) in either Debug or
// Release. This fixture therefore serves as a forward regression guard for the shape UIKit
// historically choked on — proving the deferred funnel keeps convenience/designated-init view
// controllers crash-free — rather than a proven reproduction of the historical crash.
final class ConvenienceInitViewController: UITableViewController {

    static let accessibilityIdentifier = "convenienceInitScreen"

    private var payload: String?

    /// Convenience initializer — the shape that crashed under the old GH-1361 init swizzling.
    convenience init() {
        self.init(payload: "repro")
    }

    /// Custom designated initializer, no `@objc`, calling `super.init(style:)`.
    init(payload: String) {
        super.init(style: .plain)
        self.payload = payload
    }

    /// Storyboard/`NSKeyedUnarchiver` path — exercises `initWithCoder:`, the other init the SDK
    /// swizzles.
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "ConvenienceInit #1355"

        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = """
        This screen reproduces GH-1355.

        It is a UITableViewController with a convenience initializer that delegates to a custom \
        designated initializer (no @objc), instantiated via its convenience init (payload: \
        \(payload ?? "nil")). The old init swizzling crashed this shape on iOS 15 with a \
        missing-trait-collection exception; the deferred first-instantiation swizzling must not.
        """
        label.accessibilityIdentifier = ConvenienceInitViewController.accessibilityIdentifier
        tableView.backgroundView = label
    }
}
