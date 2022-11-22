import Foundation
import UIKit

extension UIView {
    /// A shortcut to disable `translatesAutoresizingMaskIntoConstraints`
    /// - Returns: self
    func forAutoLayout() -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        return self
    }
}
