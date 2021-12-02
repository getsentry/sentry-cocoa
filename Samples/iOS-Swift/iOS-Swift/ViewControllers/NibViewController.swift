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
        
        span = SentrySDK.span
        spanObserver = SpanObserver(span: span!.rootSpan()!)
        spanObserver?.performOnFinish {
            self.assertTransaction()
        }
    }
    
    func assertTransaction() {
        UIAssert.notNil(self.span, "Transaction was not created")
        
        let children = self.span?.children()
                
        let expectation = 5
        
        UIAssert.isEqual(children?.count, expectation, "Transaction did not complete. Expecting \(expectation), got \(children?.count ?? 0)")
               
        spanObserver?.releaseOnFinish()
        UIAssert.hasViewControllerLifeCycle(self.span!, "TraceTestViewController")
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
