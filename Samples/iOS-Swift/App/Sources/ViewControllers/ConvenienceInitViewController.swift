import UIKit

// `UITableViewController` with a convenience init delegating to a custom designated init that calls
// `super.init(style:)`, deliberately without `@objc`. GH-1355 reported this shape crashing under
// the SDK's init swizzling on iOS 15 with `NSInternalInconsistencyException: missing initial trait
// collection`; the hypothesis in the fix PR (#1361) was that swizzling added methods to the
// subclass from inside the initializer, mutating the class mid-init.
//
// That root cause was never confirmed, and the crash could not be reproduced on the iOS 15.5
// simulator. So this is a forward guard, not a proven repro: any change that re-introduces init
// swizzling — GH-8548's deferred-swizzling work funnels through first instantiation — must keep
// this shape crash-free.
final class ConvenienceInitViewController: UITableViewController {

    static let accessibilityIdentifier = "convenienceInitScreen"

    private var payload: String?

    /// The reported shape: a convenience init that delegates to a custom designated init rather
    /// than to a `UIViewController` one. This is the entry point `ExtraViewController` uses.
    convenience init() {
        self.init(payload: "repro")
    }

    /// Custom designated init. Intentionally not `@objc` — the reported crash involved a
    /// Swift-only initializer, so exposing it to the runtime would change what is being tested.
    init(payload: String) {
        super.init(style: .plain)
        self.payload = payload
    }

    /// Required by `UIViewController`. Unused here (the fixture is pushed in code, not unarchived),
    /// but it keeps `initWithCoder:` compiled in as a second swizzlable init on this class.
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
        Convenience-init regression fixture (payload: \(payload ?? "nil")).
        Reported crashing under init swizzling on iOS 15 (GH-1355). Reaching this screen means it
        did not crash.
        """
        label.accessibilityIdentifier = ConvenienceInitViewController.accessibilityIdentifier
        tableView.backgroundView = label
    }
}
