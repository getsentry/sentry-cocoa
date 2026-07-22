// swiftlint:disable missing_docs
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
#if os(iOS) || os(tvOS)
import Foundation
import UIKit
#if os(iOS)
import WebKit
#endif

@objcMembers
@_spi(Private) public final class SentryRedactViewHelper: NSObject {
    private static let associatedRedactObjectKey = AssociatedObjectAccessor<Bool>.Key()
    private static let associatedIgnoreObjectKey = AssociatedObjectAccessor<Bool>.Key()
    private static let associatedClipOutObjectKey = AssociatedObjectAccessor<Bool>.Key()
    private static let associatedSwiftUIRedactObjectKey = AssociatedObjectAccessor<Bool>.Key()

    override private init() {}

    @_spi(Private) public static func maskView(_ view: UIView) {
        accessor(on: view, key: associatedRedactObjectKey).set(true)
    }

    static func shouldMaskView(_ view: UIView) -> Bool {
        value(on: view, key: associatedRedactObjectKey)
    }

    static func shouldUnmask(_ view: UIView) -> Bool {
        value(on: view, key: associatedIgnoreObjectKey)
    }

    @_spi(Private) public static func unmaskView(_ view: UIView) {
        accessor(on: view, key: associatedIgnoreObjectKey).set(true)
    }

    static func shouldClipOut(_ view: UIView) -> Bool {
        value(on: view, key: associatedClipOutObjectKey)
    }

    static public func clipOutView(_ view: UIView) {
        accessor(on: view, key: associatedClipOutObjectKey).set(true)
    }

    static func shouldRedactSwiftUI(_ view: UIView) -> Bool {
        value(on: view, key: associatedSwiftUIRedactObjectKey)
    }

    static public func maskSwiftUI(_ view: UIView) {
        accessor(on: view, key: associatedSwiftUIRedactObjectKey).set(true)
    }

    private static func accessor(
        on view: UIView,
        key: AssociatedObjectAccessor<Bool>.Key
    ) -> AssociatedObjectAccessor<Bool> {
        .init(
            on: view,
            key: key,
            policy: .OBJC_ASSOCIATION_RETAIN_NONATOMIC,
            decode: { ($0 as? NSNumber)?.boolValue },
            encode: { NSNumber(value: $0) }
        )
    }

    private static func value(
        on view: UIView,
        key: AssociatedObjectAccessor<Bool>.Key
    ) -> Bool {
        value(from: accessor(on: view, key: key).value)
    }

    @nonobjc static func value(
        from associatedValue: AssociatedObjectAccessor<Bool>.Value?
    ) -> Bool {
        switch associatedValue {
        case .none:
            return false
        case .some(.valid(let value)):
            return value
        case .some(.invalid(let value)):
            SentrySDKLog.error(
                "An invalid associated object value was set in SentryRedactViewHelper: \(value). Returning false."
            )
            return false
        }
    }
}

#endif
#endif
// swiftlint:enable missing_docs
