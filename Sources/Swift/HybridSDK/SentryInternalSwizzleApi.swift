@_implementationOnly import _SentryPrivate
import Foundation

/// APIs intended for Sentry hybrid SDKs (React Native, Flutter, .NET, Unity).
///
/// These methods are public for consumption by wrapper SDKs that bridge
/// between native and managed runtimes. They may change, be renamed,
/// or be removed in any minor release without prior deprecation.
///
/// App developers: prefer the standard `SentrySDK` API surface instead.
@_spi(Private) public final class SentryInternalSwizzleApi {

    /// Controls how often a swizzle is applied.
    public enum Mode {
        /// Swizzle every time, even if already swizzled.
        case always
        /// Swizzle only once per class (recommended default).
        case oncePerClass
        /// Swizzle only if neither this class nor any superclass was swizzled.
        case oncePerClassAndSuperclasses
    }

    /// Swizzles an instance method, replacing it with a new implementation
    /// created by the factory block.
    ///
    /// The factory block receives a closure that returns the original `IMP`.
    /// The caller must cast it to the correct function signature.
    /// Return a block whose signature matches the swizzled method
    /// (first two implicit parameters are `self` and `_cmd`).
    @discardableResult
    public func instanceMethod(
        _ selector: Selector,
        in cls: AnyClass,
        mode: Mode = .oncePerClass,
        key: UnsafeRawPointer,
        factory: @escaping (_ getOriginalImplementation: @escaping () -> IMP) -> Any
    ) -> Bool {
        let swizzleMode: SentrySwizzleMode = switch mode {
        case .always: .always
        case .oncePerClass: .oncePerClass
        case .oncePerClassAndSuperclasses: .oncePerClassAndSuperclasses
        }
        return SentrySwizzle.swizzleInstanceMethod(
            selector,
            in: cls,
            newImpFactory: { swizzleInfo in
                factory {
                    guard let info = swizzleInfo else {
                        return unsafeBitCast(0, to: IMP.self)
                    }
                    return unsafeBitCast(
                        info.getOriginalImplementation(),
                        to: IMP.self
                    )
                }
            },
            mode: swizzleMode,
            key: key
        )
    }
}
