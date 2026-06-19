// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

/// Provides method swizzling for hybrid SDKs.
public struct SentryInternalSwizzleApi {

    /// Swizzle mode controlling when a method is swizzled.
    public enum Mode: UInt {
        /// Swizzle every time, even if already swizzled.
        case always = 0
        /// Swizzle only once per class (recommended default).
        case oncePerClass = 1
        /// Swizzle only if neither this class nor any superclass was swizzled.
        case oncePerClassAndSuperclasses = 2
    }

    init() {}

    /// Swizzles an instance method on the given class.
    ///
    /// The factory receives a closure that returns the original implementation as an `IMP`.
    /// The caller casts it to the correct function pointer type and returns a new block
    /// (as `Any`) that becomes the replacement implementation.
    ///
    /// - Parameters:
    ///   - selector: The selector of the instance method to swizzle.
    ///   - classToSwizzle: The class whose method implementation will be replaced.
    ///   - mode: Controls whether re-swizzling is allowed for the same class/superclass.
    ///   - key: A unique pointer that identifies this swizzle operation. Used internally
    ///     to track whether a method was already swizzled. Callers should use the address
    ///     of a static variable (e.g. `&myKey`) so the pointer is stable across calls.
    ///   - factory: A block that receives a "get original IMP" closure and returns the
    ///     replacement implementation block.
    /// - Returns: `true` if successfully swizzled, `false` if swizzling was already
    ///   done for the given key and class.
    @discardableResult
    public func instanceMethod(
        _ selector: Selector,
        in classToSwizzle: AnyClass,
        mode: Mode,
        key: UnsafeRawPointer,
        factory: @escaping (@escaping () -> IMP) -> Any
    ) -> Bool {
        guard let swizzleMode = SentrySwizzleMode(rawValue: mode.rawValue) else {
            return false
        }
        return SentrySwizzleWrapperHelper.swizzleInstanceMethod(
            selector,
            in: classToSwizzle,
            mode: swizzleMode,
            key: key,
            factory: factory
        )
    }
}
// swiftlint:enable missing_docs
