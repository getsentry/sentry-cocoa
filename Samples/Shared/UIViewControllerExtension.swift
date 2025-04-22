import Foundation
import Sentry
import UIKit

extension UIViewController {
    func createTransactionObserver(forCallback: @escaping (Span) -> Void) -> SpanObserver? {
        let result = SpanObserver(callback: forCallback)
        if result == nil {
            UIAssert.fail("Transaction was not created")
        }
        return result
    }

    func highlightButton(_ sender: UIButton) {
        let originalLayerColor = sender.layer.backgroundColor
        let originalTitleColor = sender.titleColor(for: .normal)
        sender.layer.backgroundColor = UIColor.blue.cgColor
        sender.setTitleColor(.white, for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            sender.layer.backgroundColor = originalLayerColor
            sender.setTitleColor(originalTitleColor, for: .normal)
            sender.titleLabel?.textColor = originalTitleColor
        }
    }
}
