import Foundation
import Sentry
import UIKit

class SplitViewController: UISplitViewController {
    @available(iOS 14.0, *)
    override init(style: UISplitViewController.Style) {
        super.init(style: style)
        initialize()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
    }
    
    private func initialize() {
        self.modalPresentationStyle = .fullScreen
    }
}

class SplitRootViewController: UIViewController {

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
    }
    
    @IBAction func close() {
        parent?.dismiss(animated: false, completion: nil)
    }
    
    @IBAction func showSecondary() {
        splitViewController?.showDetailViewController(SecondarySplitViewController(), sender: nil)
    }
}

class SecondarySplitViewController: UIViewController {
    
    var spanObserver: SpanObserver?
    var assertView: AssertView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        
        assertView = AssertView().forAutoLayout()
        assertView.autoHide = false
        
        view.addSubview(assertView)
        
        let constraints = [
            assertView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0),
            assertView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0),
            assertView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ]
        NSLayoutConstraint.activate(constraints)

        spanObserver = createTransactionObserver(forCallback: assertTransaction)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SentrySDK.reportFullyDisplayed()
        
        if let topvc = TopViewControllerInspector.shared {
            topvc.bringToFront()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SentrySDK.reportFullyDisplayed()
    }
     
    func assertTransaction(span: Span) {
        spanObserver?.releaseOnFinish()
        UIAssert.shared.targetView = assertView
        UIAssert.checkForViewControllerLifeCycle(span, viewController: "SplitViewSecondaryController")
        UIAssert.shared.targetView = nil
    }
}
