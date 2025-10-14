import UIKit

#if compiler(>=6.0)
extension UIColor: @retroactive Encodable {}
#else
extension UIColor: Encodable {}
#endif

extension UIColor {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.cgColor.components)
    }
}
