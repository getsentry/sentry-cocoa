import Foundation
import Sentry
import UIKit

class NibViewController: UIViewController {
    
    @IBOutlet var button: UIButton!
    var span: Span?
    var spanObserver: SpanObserver?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        button.backgroundColor = .black
        
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        
        if let rootSpan = SentrySDK.span?.rootSpan()  {
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
                
        let expectation = 5
        
        UIAssert.isEqual(children.count, expectation, "Transaction did not complete. Expecting \(expectation), got \(children.count)")
        UIAssert.notNil(self.span, "Transaction was not created")
                     
        spanObserver?.releaseOnFinish()
        UIAssert.hasViewControllerLifeCycle(span, "TraceTestViewController")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
}
