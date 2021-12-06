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
    
    private func initialize() {
        self.modalPresentationStyle = .fullScreen
    }
}

class SplitRootViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func close() {
        parent?.dismiss(animated: false, completion: nil)
    }
    
    @IBAction func showSecondary() {
            splitViewController?.showDetailViewController(SplitViewSecondaryController(), sender: nil)
    }
    
}

class SplitViewSecondaryController: UIViewController {
    
    var spanObserver: SpanObserver?
       
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        spanObserver = createTransactionObserver(forCallback: assertTransaction(span:))
    }
    
    func assertTransaction(span: Span) {
        spanObserver?.releaseOnFinish()
        UIAssert.shared.targetView = self.view
        UIAssert.checkForViewControllerLifeCycle(span, expectingSpans: 11, viewController: "SplitViewSecondaryController")
        UIAssert.shared.targetView = nil
    }

}
