import Foundation

extension Array {
    /// Returns element at the given index if it's within bounds, otherwise returns nil.
    func element(at index: Int) -> Element? {
        guard index >= 0, index < count else {
            return nil
        }
        return self[index]
    }
}
