import UIKit

// Repro for GH-1355: a `UITableViewController` whose convenience init delegates to a custom
// designated init. Reported crashing under the SDK's init swizzling on iOS 15 with
// `NSInternalInconsistencyException: missing initial trait collection`.
//
// Deferred first-instantiation swizzling re-introduces init swizzling, so this shape must stay
// crash-free. Does not currently crash — the reported crash does not reproduce on the iOS 15.5
// simulator, so this is a guard rather than a live repro.
final class ConvenienceInitViewController: UITableViewController {

    static let accessibilityIdentifier = "convenienceInitScreen"

    private var payload: String?

    /// The reported shape: convenience init delegating to a custom designated init.
    convenience init() {
        self.init(payload: "repro")
    }

    /// Intentionally not `@objc`, matching the report.
    init(payload: String) {
        super.init(style: .plain)
        self.payload = payload
    }

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
        Reported crashing under init swizzling on iOS 15 (GH-1355).
        """
        label.accessibilityIdentifier = ConvenienceInitViewController.accessibilityIdentifier
        tableView.backgroundView = label
    }
}
