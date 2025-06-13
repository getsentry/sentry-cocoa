import Foundation

public extension Array {
    func element(at index: Int) -> Self.Element? {
        guard index < count else {
            return nil
        }
        return self[index]
    }
}
