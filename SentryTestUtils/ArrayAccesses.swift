import Foundation

public extension Array {
    func element(at index: Int) -> Self.Element? {
        guard count >= index else {
            return nil
        }
        return self[index]
    }
}
