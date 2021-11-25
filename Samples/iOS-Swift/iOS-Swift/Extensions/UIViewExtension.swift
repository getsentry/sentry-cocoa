import Foundation
import UIKit

extension UIView {
    
    var safeOrMarginGuide: UILayoutGuide {
        var guide: UILayoutGuide!
        
        if #available(iOS 11.0, *) {
            guide = self.safeAreaLayoutGuide
        } else {
            guide = self.layoutMarginsGuide
        }
        
        return guide
    }
    
}
