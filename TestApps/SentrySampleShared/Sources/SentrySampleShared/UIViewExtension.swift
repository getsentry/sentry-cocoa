#if !os(macOS) && !os(watchOS)

import Foundation
import UIKit

public extension UIView {
    /// A shortcut to disable `translatesAutoresizingMaskIntoConstraints`
    /// - Returns: self
    func forAutoLayout() -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        return self
    }

    func matchEdgeAnchors(from other: UIView, leadingPad: CGFloat = 0, trailingPad: CGFloat = 0, topPad: CGFloat = 0, bottomPad: CGFloat = 0, safeArea: Bool = false) {
        self.translatesAutoresizingMaskIntoConstraints = false
        other.translatesAutoresizingMaskIntoConstraints = false
        let layoutGuide = safeArea ? other.safeAreaLayoutGuide : other.layoutMarginsGuide
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: layoutGuide.leadingAnchor, constant: leadingPad),
            trailingAnchor.constraint(equalTo: layoutGuide.trailingAnchor, constant: -trailingPad),
            topAnchor.constraint(equalTo: layoutGuide.topAnchor, constant: topPad),
            bottomAnchor.constraint(equalTo: layoutGuide.bottomAnchor, constant: -bottomPad)
        ])
    }
}

#endif // !os(macOS) && !os(watchOS)
