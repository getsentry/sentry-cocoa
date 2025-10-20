#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import Foundation
import ObjectiveC.NSObjCRuntime
import UIKit

final class SentryRedactRegion: Equatable {
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

    static func == (lhs: SentryRedactRegion, rhs: SentryRedactRegion) -> Bool {
        guard lhs.size == rhs.size else {
            return false
        }
        guard lhs.transform == rhs.transform else {
            return false
        }
        guard lhs.type == rhs.type else {
            return false
        }
        guard lhs.color == rhs.color else {
            return false
        }
        guard lhs.name == rhs.name else {
            return false
        }
        return true
    }
}
#endif
#endif
