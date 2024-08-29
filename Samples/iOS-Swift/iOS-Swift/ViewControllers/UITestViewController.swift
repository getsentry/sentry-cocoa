import Foundation


class UITestViewController : UIViewController {
    
    @IBOutlet var transparentView : UIView!
    
    @IBOutlet var label : UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        transparentView.backgroundColor = .green
        transparentView.transform = CGAffineTransform(rotationAngle: 45 * .pi / 180.0)
    }
    
    @IBAction func showAlert(_ sender: UIButton) {
        
    }
    
}
