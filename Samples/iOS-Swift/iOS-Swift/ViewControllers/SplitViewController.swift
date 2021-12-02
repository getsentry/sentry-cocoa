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
    
        if let rootSpan = SentrySDK.span?.rootSpan() {
            spanObserver = SpanObserver(span: rootSpan)
            spanObserver?.performOnFinish {
                self.assertTransaction()
            }
        }
    }
   
    func assertTransaction() {
        guard let span = self.span else {
            UIAssert.fail("Transaction was not created")
            return
        }
        
        guard let children = span.children() else {
            UIAssert.fail("Transaction has no children")
            return
        }
                
        let expectation = 11
        
        UIAssert.isEqual(children.count, expectation, "Transaction did not complete. Expecting \(expectation), got \(children.count)")
        
        spanObserver?.releaseOnFinish()
        
        UIAssert.hasViewControllerLifeCycle(span, "TraceTestViewController")

    }
}
