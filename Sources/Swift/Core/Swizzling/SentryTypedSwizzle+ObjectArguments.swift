internal import _SentryPrivate
import Foundation

/// One explicit Objective-C object argument, forwarded to the original implementation unchanged.
typealias SentrySwizzleObjectArguments1 = AnyObject?

/// Two explicit Objective-C object arguments, forwarded to the original implementation unchanged.
typealias SentrySwizzleObjectArguments2 = (AnyObject?, AnyObject?)

/// Three explicit Objective-C object arguments, forwarded to the original implementation unchanged.
typealias SentrySwizzleObjectArguments3 = (AnyObject?, AnyObject?, AnyObject?)

/// Four explicit Objective-C object arguments, forwarded to the original implementation unchanged.
// swiftlint:disable:next large_tuple
typealias SentrySwizzleObjectArguments4 = (AnyObject?, AnyObject?, AnyObject?, AnyObject?)

/// Overloads for methods whose explicit arguments and result are all Objective-C objects and that
/// the interceptor observes without replacing any argument.
///
/// Arguments stay `AnyObject?` so they are forwarded without bridging. A bridged Swift value type
/// would trap on a `nil` that Objective-C callers can pass despite a nonnull annotation.
extension SentryTypedSwizzle {
    /// Swizzles an instance method with one object argument and an object result.
    ///
    /// The interceptor must invoke the original closure exactly where the original method should
    /// execute and return its result.
    ///
    /// - Parameters:
    ///   - classToSwizzle: The class whose instance method is replaced.
    ///   - method: The selector, expected receiving-object type, and Objective-C runtime signature.
    ///   - mode: The deduplication behavior for this swizzle installation.
    ///   - key: The stable identity used by `mode`.
    ///   - interceptor: The typed replacement behavior and access to the original implementation.
    /// - Returns: `true` when the swizzle was installed, or `false` when validation or deduplication
    ///   prevented installation.
    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentrySwizzleObjectArguments1, AnyObject?>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (Receiver, @escaping () -> AnyObject?) -> AnyObject?
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
            { receiver, first in
                let callOriginal: () -> AnyObject? = {
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (AnyObject, Selector, AnyObject?) -> AnyObject?).self
                    )
                    return original(receiver, method.selector, first)
                }

                guard let typedReceiver = receiver as? Receiver else {
                    SentrySDKLog.error("Unexpected swizzle receiver for \(NSStringFromSelector(method.selector))")
                    return callOriginal()
                }
                return interceptor(typedReceiver, callOriginal)
            } as @convention(block) (AnyObject, AnyObject?) -> AnyObject?
        }
    }

    /// Swizzles an instance method with two object arguments and an object result.
    ///
    /// The interceptor must invoke the original closure exactly where the original method should
    /// execute and return its result.
    ///
    /// - Parameters:
    ///   - classToSwizzle: The class whose instance method is replaced.
    ///   - method: The selector, expected receiving-object type, and Objective-C runtime signature.
    ///   - mode: The deduplication behavior for this swizzle installation.
    ///   - key: The stable identity used by `mode`.
    ///   - interceptor: The typed replacement behavior and access to the original implementation.
    /// - Returns: `true` when the swizzle was installed, or `false` when validation or deduplication
    ///   prevented installation.
    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentrySwizzleObjectArguments2, AnyObject?>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (Receiver, @escaping () -> AnyObject?) -> AnyObject?
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
            { receiver, first, second in
                let callOriginal: () -> AnyObject? = {
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (AnyObject, Selector, AnyObject?, AnyObject?) -> AnyObject?).self
                    )
                    return original(receiver, method.selector, first, second)
                }

                guard let typedReceiver = receiver as? Receiver else {
                    SentrySDKLog.error("Unexpected swizzle receiver for \(NSStringFromSelector(method.selector))")
                    return callOriginal()
                }
                return interceptor(typedReceiver, callOriginal)
            } as @convention(block) (AnyObject, AnyObject?, AnyObject?) -> AnyObject?
        }
    }

    /// Swizzles an instance method with three object arguments and an object result.
    ///
    /// The interceptor must invoke the original closure exactly where the original method should
    /// execute and return its result.
    ///
    /// - Parameters:
    ///   - classToSwizzle: The class whose instance method is replaced.
    ///   - method: The selector, expected receiving-object type, and Objective-C runtime signature.
    ///   - mode: The deduplication behavior for this swizzle installation.
    ///   - key: The stable identity used by `mode`.
    ///   - interceptor: The typed replacement behavior and access to the original implementation.
    /// - Returns: `true` when the swizzle was installed, or `false` when validation or deduplication
    ///   prevented installation.
    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentrySwizzleObjectArguments3, AnyObject?>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (Receiver, @escaping () -> AnyObject?) -> AnyObject?
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
            { receiver, first, second, third in
                let callOriginal: () -> AnyObject? = {
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (AnyObject, Selector, AnyObject?, AnyObject?, AnyObject?) -> AnyObject?).self
                    )
                    return original(receiver, method.selector, first, second, third)
                }

                guard let typedReceiver = receiver as? Receiver else {
                    SentrySDKLog.error("Unexpected swizzle receiver for \(NSStringFromSelector(method.selector))")
                    return callOriginal()
                }
                return interceptor(typedReceiver, callOriginal)
            } as @convention(block) (AnyObject, AnyObject?, AnyObject?, AnyObject?) -> AnyObject?
        }
    }

    /// Swizzles an instance method with four object arguments and an object result.
    ///
    /// The interceptor must invoke the original closure exactly where the original method should
    /// execute and return its result.
    ///
    /// - Parameters:
    ///   - classToSwizzle: The class whose instance method is replaced.
    ///   - method: The selector, expected receiving-object type, and Objective-C runtime signature.
    ///   - mode: The deduplication behavior for this swizzle installation.
    ///   - key: The stable identity used by `mode`.
    ///   - interceptor: The typed replacement behavior and access to the original implementation.
    /// - Returns: `true` when the swizzle was installed, or `false` when validation or deduplication
    ///   prevented installation.
    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentrySwizzleObjectArguments4, AnyObject?>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (Receiver, @escaping () -> AnyObject?) -> AnyObject?
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
            { receiver, first, second, third, fourth in
                let callOriginal: () -> AnyObject? = {
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (AnyObject, Selector, AnyObject?, AnyObject?, AnyObject?, AnyObject?) -> AnyObject?).self
                    )
                    return original(receiver, method.selector, first, second, third, fourth)
                }

                guard let typedReceiver = receiver as? Receiver else {
                    SentrySDKLog.error("Unexpected swizzle receiver for \(NSStringFromSelector(method.selector))")
                    return callOriginal()
                }
                return interceptor(typedReceiver, callOriginal)
            } as @convention(block) (AnyObject, AnyObject?, AnyObject?, AnyObject?, AnyObject?) -> AnyObject?
        }
    }
}
