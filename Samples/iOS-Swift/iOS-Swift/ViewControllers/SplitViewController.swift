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
    var assertView: AssertView!
    var processLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        
        assertView = AssertView()
        assertView.autoHide = false
        assertView.translatesAutoresizingMaskIntoConstraints = false
       
        processLabel = UILabel()
        processLabel.text = ""
        processLabel.numberOfLines = 0
        processLabel.textColor = UIColor.black
        processLabel.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(assertView)
        view.addSubview(processLabel)
        
        let constraints = [
            assertView.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0),
            assertView.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0),
            assertView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ]
        NSLayoutConstraint.activate(constraints)
        
        let labelConstraints = [
            processLabel.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 16),
            processLabel.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -16),
            processLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16)
        ]
        NSLayoutConstraint.activate(labelConstraints)
        
        log("ViewDidLoad")
        spanObserver = createTransactionObserver(forCallback: assertTransaction)
        
        if spanObserver != nil {
            log("Observing Transaction")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        log("ViewDidAppear")
        super.viewDidAppear(animated)
    }
    
    func log(_ text: String) {
        processLabel.text! += "\(text)\n"
    }
    
    func assertTransaction(span: Span) {
        log("Asserting Transaction")
        spanObserver?.releaseOnFinish()
        UIAssert.shared.targetView = assertView
        UIAssert.checkForViewControllerLifeCycle(span, expectingSpans: 11, viewController: "SplitViewSecondaryController")
        UIAssert.shared.targetView = nil
        log("Asserting Ended")
    }

}
