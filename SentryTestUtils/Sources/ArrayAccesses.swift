// swiftlint:disable missing_docs
import Foundation

public extension Array {
    func element(at index: Int) -> Self.Element? {
        guard index >= 0, index < count else {
            return nil
        }
        return self[index]
    }
}
// swiftlint:enable missing_docs
