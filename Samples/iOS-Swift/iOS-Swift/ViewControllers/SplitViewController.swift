import Foundation
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        
        let label = UILabel()
        label.text = "This is Split Secondary Controller"
        
        label.sizeToFit()
        label.center = view.center
        
        view.addSubview(label)
    }
}
