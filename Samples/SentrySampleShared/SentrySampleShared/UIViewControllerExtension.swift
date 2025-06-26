#if !os(macOS) && !os(watchOS)

import Foundation
import Sentry
import UIKit

public extension UIViewController {
    func createTransactionObserver(forCallback: @escaping (Span) -> Void) -> SpanObserver? {
        let result = SpanObserver { span in
          // This callback may not be on the main queue, but `forCallback` is always called on the main queue.
          DispatchQueue.main.async {
            forCallback(span)
          }
        }
        if result == nil {
          print("Could not create transaction observer")
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

#endif // !os(macOS) && !os(watchOS)
