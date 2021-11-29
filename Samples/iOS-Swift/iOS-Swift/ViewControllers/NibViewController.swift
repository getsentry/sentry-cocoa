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
                
        UIAssert.isEqual(children?.count, 4, "Transaction did not complete")
               
        spanObserver?.releaseOnFinish()
        UIAssert.hasViewControllerLifeCycle(self.span!, "TraceTestViewController")

    }
}
