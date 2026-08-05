import UIKit

// `UITableViewController` with a convenience init delegating to a custom designated init that calls
// `super.init(style:)`, deliberately without `@objc`. This shape crashed under the SDK's old
// UIViewController init swizzling on iOS 15 with `NSInternalInconsistencyException: missing initial
// trait collection` — the old funnel mutated the subclass's method list from inside the initializer,
// before calling the original init.
//
// Any future change that re-introduces init swizzling must keep this shape crash-free. The
// historical crash could not be reproduced on the iOS 15.5 simulator, so this fixture is a forward
// regression guard rather than a proven repro. (GH-1355)
final class ConvenienceInitViewController: UITableViewController {

    static let accessibilityIdentifier = "convenienceInitScreen"

    private var payload: String?

    /// Crashing shape: convenience init delegating to a custom designated init.
    convenience init() {
        self.init(payload: "repro")
    }

    /// No `@objc`, calls `super.init(style:)`.
    init(payload: String) {
        super.init(style: .plain)
        self.payload = payload
    }

    /// Storyboard/`NSKeyedUnarchiver` path — exercises `initWithCoder:`.
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
        The old init swizzling crashed this shape on iOS 15; deferred swizzling must not.
        """
        label.accessibilityIdentifier = ConvenienceInitViewController.accessibilityIdentifier
        tableView.backgroundView = label
    }
}
