internal import _SentryPrivate
import Foundation
import ObjectiveC

/// Installs typed Objective-C instance method swizzles after validating their runtime signatures.
///
/// Each overload exposes a Swift interceptor whose receiver, arguments, and result match a supported
/// Objective-C calling convention. The receiver is the object receiving the message, equivalent to
/// `self` inside the swizzled method. Validation must succeed before an implementation is replaced.
enum SentryTypedSwizzle {
    /// A stable identity used with `SentrySwizzleMode` to deduplicate swizzle installations.
    ///
    /// Keep the key alive for as long as its swizzle identity is needed. Different key instances
    /// always have different identities, even when used for the same method.
    struct Key {
        /// A reference type whose stable address provides the key's identity across `Key` copies.
        private final class Token {}

        /// The token retained for the lifetime of this key and all of its copies.
        private let token = Token()

        /// The stable pointer passed to the Objective-C swizzling implementation.
        var pointer: UnsafeRawPointer {
            UnsafeRawPointer(Unmanaged.passUnretained(token).toOpaque())
        }
    }

    /// Swizzles an instance method that takes no explicit arguments and returns `Void`.
    ///
    /// The interceptor receives the typed receiver, which is the instance receiving the Objective-C
    /// message, and a closure that invokes the current original implementation. The interceptor must
    /// invoke that closure exactly where the original method should execute.
    ///
    /// - Parameters:
    ///   - classToSwizzle: The class whose instance method is replaced.
    ///   - method: The selector, expected receiving-object type, and Objective-C runtime signature.
    ///   - mode: The deduplication behavior for this swizzle installation.
    ///   - key: The stable identity used by `mode`.
    ///   - interceptor: The typed replacement behavior. Its first argument is the object receiving
    ///     the message, followed by access to the original implementation.
    /// - Returns: `true` when the swizzle was installed, or `false` when validation or deduplication
    ///   prevented installation.
    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, Void, Void>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (Receiver, @escaping () -> Void) -> Void
    ) -> Bool {
        guard validate(in: classToSwizzle, method: method) else {
            return false
        }

        return SentrySwizzleWrapperHelper.swizzleInstanceMethod(
            method.selector,
            in: classToSwizzle,
            mode: mode,
            key: key.pointer
        ) { getOriginal in
            { receiver in
                let callOriginal: (AnyObject) -> Void = { receiver in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (AnyObject, Selector) -> Void).self
                    )
                    original(receiver, method.selector)
                }

                guard let typedReceiver = receiver as? Receiver else {
                    SentrySDKLog.error("Unexpected swizzle receiver for \(NSStringFromSelector(method.selector))")
                    return callOriginal(receiver)
                }

                interceptor(typedReceiver) {
                    callOriginal(receiver)
                }
            } as @convention(block) (AnyObject) -> Void
        }
    }

    /// Validates that an Objective-C instance method matches a typed method descriptor.
    ///
    /// - Parameters:
    ///   - classToSwizzle: The class expected to contain the descriptor's instance method.
    ///   - method: The selector, expected receiving-object type, and Objective-C runtime signature.
    /// Validation failures are logged before this method returns.
    ///
    /// - Returns: `true` when the receiver and complete method signature are compatible.
    static func validate<Receiver, Arguments, Result>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, Arguments, Result>
    ) -> Bool {
        guard let failure = validationFailure(in: classToSwizzle, method: method) else {
            return true
        }

        SentrySDKLog.error(failure)
        return false
    }

    /// Returns a diagnostic when an Objective-C instance method does not match a typed descriptor.
    ///
    /// - Parameters:
    ///   - classToSwizzle: The class expected to contain the descriptor's instance method.
    ///   - expectedMethod: The selector, expected receiving-object type, and Objective-C runtime
    ///     signature.
    /// - Returns: A diagnostic describing the first mismatch, or `nil` when validation succeeds.
    static func validationFailure<Receiver, Arguments, Result>(
        in classToSwizzle: AnyClass,
        method expectedMethod: SentrySwizzleMethod<Receiver, Arguments, Result>
    ) -> String? {
        guard classToSwizzle is Receiver.Type else {
            return "Swizzle receiver mismatch for \(NSStringFromClass(classToSwizzle)): expected \(NSStringFromClass(expectedMethod.receiver))"
        }

        guard let method = class_getInstanceMethod(classToSwizzle, expectedMethod.selector) else {
            return "Swizzle method not found: \(NSStringFromClass(classToSwizzle)).\(NSStringFromSelector(expectedMethod.selector))"
        }

        let actualSignature = SentrySwizzleMethod<Receiver, Arguments, Result>.Signature(
            returnType: .init(encoding: copyReturnType(of: method)),
            arguments: (0..<method_getNumberOfArguments(method)).map {
                .init(encoding: copyArgumentType(of: method, at: $0))
            }
        )
        guard expectedMethod.signature.matches(actualSignature) else {
            return "Swizzle signature mismatch for \(NSStringFromClass(classToSwizzle)).\(NSStringFromSelector(expectedMethod.selector)): expected \(expectedMethod.signature), actual \(actualSignature)"
        }

        return nil
    }

    /// Copies an Objective-C method's return type encoding into Swift-managed storage.
    ///
    /// - Parameter method: The Objective-C runtime method to inspect.
    /// - Returns: The method's return type encoding.
    private static func copyReturnType(of method: Method) -> String {
        let encoding = method_copyReturnType(method)
        defer { free(encoding) }
        return String(cString: encoding)
    }

    /// Copies an Objective-C method argument's type encoding into Swift-managed storage.
    ///
    /// - Parameters:
    ///   - method: The Objective-C runtime method to inspect.
    ///   - index: The zero-based argument index, including the implicit receiver and selector.
    /// - Returns: The argument's type encoding, or an empty string when the runtime has no encoding.
    private static func copyArgumentType(of method: Method, at index: UInt32) -> String {
        guard let encoding = method_copyArgumentType(method, index) else {
            return ""
        }
        defer { free(encoding) }
        return String(cString: encoding)
    }
}
