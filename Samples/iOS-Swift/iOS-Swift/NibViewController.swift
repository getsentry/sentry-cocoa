import Foundation
import UIKit

class NibViewController: UIViewController {
    
    @IBOutlet var button: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        button.backgroundColor = .systemPink
    }
}
