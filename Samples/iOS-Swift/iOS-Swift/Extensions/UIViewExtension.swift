import Foundation
import UIKit

extension UIView {
    /// A shortcut to disable `translatesAutoresizingMaskIntoConstraints`
    /// - Returns: self
    func forAutoLayout() -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        return self
    }
    
    func matchEdgeAnchors(from other: UIView, leadingPad: CGFloat = 0, trailingPad: CGFloat = 0, topPad: CGFloat = 0, bottomPad: CGFloat = 0) {
        self.translatesAutoresizingMaskIntoConstraints = false
        other.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: leadingPad),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: trailingPad),
            topAnchor.constraint(equalTo: other.topAnchor, constant: topPad),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: bottomPad)
        ])
    }
}
