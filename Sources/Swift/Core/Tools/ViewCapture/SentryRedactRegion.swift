#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import Foundation
import ObjectiveC.NSObjCRuntime
import UIKit

@objc @_spi(Private) public class SentryRedactRegion: NSObject {
    let size: CGSize
    let transform: CGAffineTransform
    let type: SentryRedactRegionType
    let color: UIColor?
    let name: String

    init(size: CGSize, transform: CGAffineTransform, type: SentryRedactRegionType, color: UIColor? = nil, name: String) {
        self.size = size
        self.transform = transform
        self.type = type
        self.color = color
        self.name = name
    }

    func canReplace(as other: SentryRedactRegion) -> Bool {
        size == other.size && transform == other.transform && type == other.type
    }

    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? SentryRedactRegion else {
            return false
        }
        guard other.size == self.size else {
            return false
        }
        guard other.color == self.color else {
            return false
        }
        guard other.type == self.type else {
            return false
        }
        guard other.color == self.color else {
            return false
        }
        guard other.name == self.name else {
            return false
        }
        return true
    }
}

extension SentryRedactRegion: Encodable {}

extension UIColor: @retroactive Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.cgColor.components)
    }
}
#endif
#endif
