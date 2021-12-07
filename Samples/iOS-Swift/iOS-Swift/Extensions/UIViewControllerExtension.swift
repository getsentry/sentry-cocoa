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
}
