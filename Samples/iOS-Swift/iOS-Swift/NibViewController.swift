import Foundation
import UIKit

class NibViewController: UIViewController {
    
    @IBOutlet var button: UIButton!
    
    override func viewDidLoad() {
        button.backgroundColor = .systemPink
    }
}
