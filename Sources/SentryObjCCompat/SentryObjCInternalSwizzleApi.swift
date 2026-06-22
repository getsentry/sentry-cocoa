// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCSwizzleMode)
public enum SentryObjCSwizzleMode: Int {
    case always = 0
    case oncePerClass = 1
    case oncePerClassAndSuperclasses = 2
}

@objc(SentryObjCInternalSwizzleApi) public final class SentryObjCInternalSwizzleApi: NSObject {
    internal let wrapped: Box<SentryInternalSwizzleApi>

    internal init(_ wrapped: SentryInternalSwizzleApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public func swizzleInstanceMethod(
        _ selector: Selector,
        inClass classToSwizzle: AnyClass,
        mode: SentryObjCSwizzleMode,
        key: UnsafeRawPointer,
        newImpFactory factory: @escaping (@escaping () -> IMP) -> Any
    ) -> Bool {
        guard let swiftMode = SentryInternalSwizzleApi.Mode(rawValue: UInt(bitPattern: mode.rawValue)) else {
            return false
        }
        return wrapped.value.instanceMethod(
            selector,
            in: classToSwizzle,
            mode: swiftMode,
            key: key,
            factory: factory
        )
    }
}
// swiftlint:enable missing_docs
