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
    var span: Span?
    var spanObserver: SpanObserver?
       
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
    
        span = SentrySDK.span
        spanObserver = SpanObserver(span: span!.rootSpan()!)
        spanObserver?.performOnFinish {
            self.assertTransaction()
        }
    }
   
    func assertTransaction() {
        UIAssert.notNil(self.span, "Transaction was not created")
        
        let children = self.span?.children()
        
        UIAssert.isEqual(children?.count, 11, "Transaction did not complete")
        
        spanObserver?.releaseOnFinish()

    }
}
