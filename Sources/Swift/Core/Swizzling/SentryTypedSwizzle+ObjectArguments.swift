internal import _SentryPrivate
import Foundation

/// One explicit Objective-C object argument of class `A`.
typealias SentrySwizzleObjectArguments1<A: AnyObject> = A?

/// Two explicit Objective-C object arguments of classes `A` and `B`.
typealias SentrySwizzleObjectArguments2<A: AnyObject, B: AnyObject> = (A?, B?)

/// Three explicit Objective-C object arguments of classes `A`, `B`, and `C`.
typealias SentrySwizzleObjectArguments3<A: AnyObject, B: AnyObject, C: AnyObject> = (A?, B?, C?)

/// Four explicit Objective-C object arguments of classes `A`, `B`, `C`, and `D`.
// swiftlint:disable:next large_tuple
typealias SentrySwizzleObjectArguments4<A: AnyObject, B: AnyObject, C: AnyObject, D: AnyObject> = (A?, B?, C?, D?)

/// Overloads for methods whose explicit arguments and result are all Objective-C objects.
///
/// Arguments and the result keep their Objective-C class types, such as `NSURLRequest` or
/// `NSString`, instead of bridging to Swift value types like `URLRequest` or `String`. A bridged
/// value type would trap on a `nil` that Objective-C callers can pass despite a nonnull annotation.
///
/// When an argument isn't of its declared class, the original implementation runs without the
/// interceptor, like it does for an unexpected receiver.
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
    static func instanceMethod<Receiver: AnyObject, A: AnyObject, R: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentrySwizzleObjectArguments1<A>, R?>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (Receiver, A?, @escaping (A?) -> R?) -> R?
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
                let callOriginal: (AnyObject?) -> AnyObject? = { first in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (AnyObject, Selector, AnyObject?) -> AnyObject?).self
                    )
                    return original(receiver, method.selector, first)
                }

                guard let typedReceiver = receiver as? Receiver,
                      let typedFirst = typedObject(first, as: A.self) else {
                    SentrySDKLog.error("Unexpected swizzle receiver or argument for \(NSStringFromSelector(method.selector))")
                    return callOriginal(first)
                }
                let result = ObjectResult<R>()
                let returned = interceptor(typedReceiver, typedFirst) { first in
                    result.capture(callOriginal(first))
                }
                return result.resolve(returned)
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
    static func instanceMethod<Receiver: AnyObject, A: AnyObject, B: AnyObject, R: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentrySwizzleObjectArguments2<A, B>, R?>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (Receiver, A?, B?, @escaping (A?, B?) -> R?) -> R?
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
                let callOriginal: (AnyObject?, AnyObject?) -> AnyObject? = { first, second in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (AnyObject, Selector, AnyObject?, AnyObject?) -> AnyObject?).self
                    )
                    return original(receiver, method.selector, first, second)
                }

                guard let typedReceiver = receiver as? Receiver,
                      let typedFirst = typedObject(first, as: A.self),
                      let typedSecond = typedObject(second, as: B.self) else {
                    SentrySDKLog.error("Unexpected swizzle receiver or argument for \(NSStringFromSelector(method.selector))")
                    return callOriginal(first, second)
                }
                let result = ObjectResult<R>()
                let returned = interceptor(typedReceiver, typedFirst, typedSecond) { first, second in
                    result.capture(callOriginal(first, second))
                }
                return result.resolve(returned)
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
    static func instanceMethod<Receiver: AnyObject, A: AnyObject, B: AnyObject, C: AnyObject, R: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentrySwizzleObjectArguments3<A, B, C>, R?>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (Receiver, A?, B?, C?, @escaping (A?, B?, C?) -> R?) -> R?
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
                let callOriginal: (AnyObject?, AnyObject?, AnyObject?) -> AnyObject? = { first, second, third in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (AnyObject, Selector, AnyObject?, AnyObject?, AnyObject?) -> AnyObject?).self
                    )
                    return original(receiver, method.selector, first, second, third)
                }

                guard let typedReceiver = receiver as? Receiver,
                      let typedFirst = typedObject(first, as: A.self),
                      let typedSecond = typedObject(second, as: B.self),
                      let typedThird = typedObject(third, as: C.self) else {
                    SentrySDKLog.error("Unexpected swizzle receiver or argument for \(NSStringFromSelector(method.selector))")
                    return callOriginal(first, second, third)
                }
                let result = ObjectResult<R>()
                let returned = interceptor(typedReceiver, typedFirst, typedSecond, typedThird) { first, second, third in
                    result.capture(callOriginal(first, second, third))
                }
                return result.resolve(returned)
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
    static func instanceMethod<Receiver: AnyObject, A: AnyObject, B: AnyObject, C: AnyObject, D: AnyObject, R: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentrySwizzleObjectArguments4<A, B, C, D>, R?>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (Receiver, A?, B?, C?, D?, @escaping (A?, B?, C?, D?) -> R?) -> R?
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
                let callOriginal: (AnyObject?, AnyObject?, AnyObject?, AnyObject?) -> AnyObject? = { first, second, third, fourth in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (AnyObject, Selector, AnyObject?, AnyObject?, AnyObject?, AnyObject?) -> AnyObject?).self
                    )
                    return original(receiver, method.selector, first, second, third, fourth)
                }

                guard let typedReceiver = receiver as? Receiver,
                      let typedFirst = typedObject(first, as: A.self),
                      let typedSecond = typedObject(second, as: B.self),
                      let typedThird = typedObject(third, as: C.self),
                      let typedFourth = typedObject(fourth, as: D.self) else {
                    SentrySDKLog.error("Unexpected swizzle receiver or argument for \(NSStringFromSelector(method.selector))")
                    return callOriginal(first, second, third, fourth)
                }
                let result = ObjectResult<R>()
                let returned = interceptor(typedReceiver, typedFirst, typedSecond, typedThird, typedFourth) { first, second, third, fourth in
                    result.capture(callOriginal(first, second, third, fourth))
                }
                return result.resolve(returned)
            } as @convention(block) (AnyObject, AnyObject?, AnyObject?, AnyObject?, AnyObject?) -> AnyObject?
        }
    }

    /// Returns `.some(nil)` for `nil`, `.some(value)` for an object of class `T`, and `nil` for an
    /// object of any other class.
    private static func typedObject<T: AnyObject>(_ value: AnyObject?, as type: T.Type) -> T?? {
        guard let value = value else {
            return .some(nil)
        }
        guard let typed = value as? T else {
            return nil
        }
        return .some(typed)
    }

    /// Converts the original result to its declared class and keeps it when it has another class,
    /// so the swizzle never drops what the original returned.
    private final class ObjectResult<T: AnyObject> {
        private var untyped: AnyObject?

        func capture(_ value: AnyObject?) -> T? {
            guard let value = value else {
                untyped = nil
                return nil
            }
            guard let typed = value as? T else {
                untyped = value
                return nil
            }
            untyped = nil
            return typed
        }

        func resolve(_ returned: T?) -> AnyObject? {
            returned ?? untyped
        }
    }
}
