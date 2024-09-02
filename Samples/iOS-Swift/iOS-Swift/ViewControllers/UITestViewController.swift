import Foundation

class TargetView: UIView {
    
}

class UITestViewController: UIViewController {
    
    @IBOutlet var transparentView: UIView!
    
    @IBOutlet var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        transparentView.backgroundColor = .green
        transparentView.transform = CGAffineTransform(rotationAngle: 45 * .pi / 180.0)
        
        SentrySDK.replayIgnore(transparentView)
      }
    
    @IBAction func showAlert(_ sender: UIButton) {
        
    }
    
}
