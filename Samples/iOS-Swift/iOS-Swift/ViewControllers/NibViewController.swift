import Foundation
import Sentry
import UIKit

class NibViewController: UIViewController {
    
    @IBOutlet var button: UIButton!
    var spanObserver: SpanObserver?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        button.backgroundColor = .black
        
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        
        spanObserver = createTransactionObserver(forCallback: assertTransaction(span:))
    }
    
    func assertTransaction(span: Span) {
        spanObserver?.releaseOnFinish()
        UIAssert.checkForViewControllerLifeCycle(span, viewController: "NibViewController")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SentrySDK.reportFullyDisplayed()
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
