// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalSwizzleApi) public final class SentryObjCInternalSwizzleApi: NSObject {
    internal let wrapped: SentryInternalSwizzleApi

    internal init(_ wrapped: SentryInternalSwizzleApi) {
        self.wrapped = wrapped
    }

    @objc @discardableResult
    public func swizzleInstanceMethod(
        _ selector: Selector,
        inClass cls: AnyClass,
        newImpFactory factoryBlock: @escaping (_ getOriginal: @escaping () -> IMP) -> Any,
        mode: SentryObjCSwizzleMode,
        key: UnsafeRawPointer
    ) -> Bool {
        let swiftMode: SentryInternalSwizzleApi.Mode = switch mode {
        case .always: .always
        case .oncePerClass: .oncePerClass
        case .oncePerClassAndSuperclasses: .oncePerClassAndSuperclasses
        @unknown default: .oncePerClass
        }
        return wrapped.instanceMethod(
            selector,
            in: cls,
            mode: swiftMode,
            key: key,
            factory: factoryBlock
        )
    }
}

/// Maps to `SentryObjCSwizzleMode` enum values defined in the ObjC header.
@objc public enum SentryObjCSwizzleMode: UInt {
    case always = 0
    case oncePerClass = 1
    case oncePerClassAndSuperclasses = 2
}
// swiftlint:enable missing_docs
