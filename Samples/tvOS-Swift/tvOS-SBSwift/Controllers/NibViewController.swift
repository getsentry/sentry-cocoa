import Foundation
import UIKit

class NibViewController: UIViewController {
    
    @IBOutlet var button: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "NibViewController"
        
        button.backgroundColor = .black
        
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        
        button.accessibilityIdentifier = "LONELY_BUTTON"
    }
}
