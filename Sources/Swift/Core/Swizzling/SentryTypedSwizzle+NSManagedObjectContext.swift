internal import _SentryPrivate
import CoreData

extension SentryTypedSwizzle {
    /// Swizzles an object-returning fetch method with a request and nullable NSError output pointer.
    /// The original closure permits argument replacement and preserves NSArray identity and nil.
    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentryCoreDataFetchArguments, NSArray?>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (
            Receiver,
            NSFetchRequest<NSFetchRequestResult>,
            NSErrorPointer,
            @escaping (NSFetchRequest<NSFetchRequestResult>, NSErrorPointer) -> NSArray?
        ) -> NSArray?
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
            { receiver, request, error in
                let callOriginal: (AnyObject, NSFetchRequest<NSFetchRequestResult>, NSErrorPointer) -> NSArray? = { receiver, request, error in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (AnyObject, Selector, NSFetchRequest<NSFetchRequestResult>, NSErrorPointer) -> NSArray?).self
                    )
                    return original(receiver, method.selector, request, error)
                }

                guard let typedReceiver = receiver as? Receiver else {
                    SentrySDKLog.error("Unexpected swizzle receiver for \(NSStringFromSelector(method.selector))")
                    return callOriginal(receiver, request, error)
                }

                return interceptor(typedReceiver, request, error) { forwardedRequest, forwardedError in
                    callOriginal(receiver, forwardedRequest, forwardedError)
                }
            } as @convention(block) (AnyObject, NSFetchRequest<NSFetchRequestResult>, NSErrorPointer) -> NSArray?
        }
    }

    /// Swizzles a BOOL-returning method with a nullable NSError output pointer.
    /// ObjCBool preserves the platform's Objective-C ABI while the interceptor uses Swift Bool.
    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, NSErrorPointer, Bool>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (Receiver, NSErrorPointer, @escaping (NSErrorPointer) -> Bool) -> Bool
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
            { receiver, error in
                let callOriginal: (AnyObject, NSErrorPointer) -> ObjCBool = { receiver, error in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (AnyObject, Selector, NSErrorPointer) -> ObjCBool).self
                    )
                    return original(receiver, method.selector, error)
                }

                guard let typedReceiver = receiver as? Receiver else {
                    SentrySDKLog.error("Unexpected swizzle receiver for \(NSStringFromSelector(method.selector))")
                    return callOriginal(receiver, error)
                }

                return ObjCBool(interceptor(typedReceiver, error) { forwardedError in
                    callOriginal(receiver, forwardedError).boolValue
                })
            } as @convention(block) (AnyObject, NSErrorPointer) -> ObjCBool
        }
    }
}
