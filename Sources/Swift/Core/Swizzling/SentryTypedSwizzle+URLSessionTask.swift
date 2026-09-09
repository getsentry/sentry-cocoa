internal import _SentryPrivate
import Foundation

extension SentryTypedSwizzle {
    /// Swizzles an instance method that accepts a URL session task state and returns `Void`.
    ///
    /// The interceptor may forward either the received state or a replacement state to the original
    /// implementation. It must invoke the original closure exactly where the original method should
    /// execute.
    ///
    /// - Parameters:
    ///   - classToSwizzle: The class whose instance method is replaced.
    ///   - method: The selector, expected receiving-object type, and Objective-C runtime signature.
    ///   - mode: The deduplication behavior for this swizzle installation.
    ///   - key: The stable identity used by `mode`.
    ///   - interceptor: The typed replacement behavior, received state, and access to the original
    ///     implementation.
    /// - Returns: `true` when the swizzle was installed, or `false` when validation or deduplication
    ///   prevented installation.
    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, URLSessionTask.State, Void>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (Receiver, URLSessionTask.State, @escaping (URLSessionTask.State) -> Void) -> Void
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
            { receiver, state in
                let callOriginal: (AnyObject, URLSessionTask.State) -> Void = { receiver, forwardedState in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (AnyObject, Selector, URLSessionTask.State) -> Void).self
                    )
                    original(receiver, method.selector, forwardedState)
                }

                guard let typedReceiver = receiver as? Receiver else {
                    SentrySDKLog.error("Unexpected swizzle receiver for \(NSStringFromSelector(method.selector))")
                    return callOriginal(receiver, state)
                }

                interceptor(typedReceiver, state) { forwardedState in
                    callOriginal(receiver, forwardedState)
                }
            } as @convention(block) (AnyObject, URLSessionTask.State) -> Void
        }
    }

    /// Swizzles a URL session data task method that accepts a request and completion handler.
    ///
    /// The interceptor may replace the request or completion handler before invoking the original
    /// implementation. It must return either the task produced by the original closure or another
    /// valid data task.
    ///
    /// - Parameters:
    ///   - classToSwizzle: The URL session class whose instance method is replaced.
    ///   - method: The selector, expected receiving-object type, and Objective-C runtime signature.
    ///   - mode: The deduplication behavior for this swizzle installation.
    ///   - key: The stable identity used by `mode`.
    ///   - interceptor: The typed replacement behavior and access to the original implementation.
    /// - Returns: `true` when the swizzle was installed, or `false` when validation or deduplication
    ///   prevented installation.
    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentryDataTaskRequestArguments, URLSessionDataTask>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (
            Receiver,
            URLRequest,
            SentryDataTaskCompletionHandler?,
            @escaping (URLRequest, SentryDataTaskCompletionHandler?) -> URLSessionDataTask
        ) -> URLSessionDataTask
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
            { receiver, request, completionHandler in
                let callOriginal: (AnyObject, URLRequest, SentryDataTaskCompletionHandler?) -> URLSessionDataTask = { receiver, request, completionHandler in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (
                            AnyObject,
                            Selector,
                            URLRequest,
                            SentryDataTaskCompletionHandler?
                        ) -> URLSessionDataTask).self
                    )
                    return original(receiver, method.selector, request, completionHandler)
                }

                guard let typedReceiver = receiver as? Receiver else {
                    SentrySDKLog.error("Unexpected swizzle receiver for \(NSStringFromSelector(method.selector))")
                    return callOriginal(receiver, request, completionHandler)
                }

                return interceptor(typedReceiver, request, completionHandler) { forwardedRequest, forwardedCompletionHandler in
                    callOriginal(receiver, forwardedRequest, forwardedCompletionHandler)
                }
            } as @convention(block) (
                AnyObject,
                URLRequest,
                SentryDataTaskCompletionHandler?
            ) -> URLSessionDataTask
        }
    }

    /// Swizzles a URL session data task method that accepts a URL and completion handler.
    ///
    /// The interceptor may replace the URL or completion handler before invoking the original
    /// implementation. It must return either the task produced by the original closure or another
    /// valid data task.
    ///
    /// - Parameters:
    ///   - classToSwizzle: The URL session class whose instance method is replaced.
    ///   - method: The selector, expected receiving-object type, and Objective-C runtime signature.
    ///   - mode: The deduplication behavior for this swizzle installation.
    ///   - key: The stable identity used by `mode`.
    ///   - interceptor: The typed replacement behavior and access to the original implementation.
    /// - Returns: `true` when the swizzle was installed, or `false` when validation or deduplication
    ///   prevented installation.
    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentryDataTaskURLArguments, URLSessionDataTask>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (
            Receiver,
            URL,
            SentryDataTaskCompletionHandler?,
            @escaping (URL, SentryDataTaskCompletionHandler?) -> URLSessionDataTask
        ) -> URLSessionDataTask
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
            { receiver, url, completionHandler in
                let callOriginal: (AnyObject, URL, SentryDataTaskCompletionHandler?) -> URLSessionDataTask = { receiver, url, completionHandler in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (
                            AnyObject,
                            Selector,
                            URL,
                            SentryDataTaskCompletionHandler?
                        ) -> URLSessionDataTask).self
                    )
                    return original(receiver, method.selector, url, completionHandler)
                }

                guard let typedReceiver = receiver as? Receiver else {
                    SentrySDKLog.error("Unexpected swizzle receiver for \(NSStringFromSelector(method.selector))")
                    return callOriginal(receiver, url, completionHandler)
                }

                return interceptor(typedReceiver, url, completionHandler) { forwardedURL, forwardedCompletionHandler in
                    callOriginal(receiver, forwardedURL, forwardedCompletionHandler)
                }
            } as @convention(block) (
                AnyObject,
                URL,
                SentryDataTaskCompletionHandler?
            ) -> URLSessionDataTask
        }
    }

    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentryDownloadTaskURLArguments, URLSessionDownloadTask>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (
            Receiver,
            URL,
            SentryDownloadTaskCompletionHandler?,
            @escaping (URL, SentryDownloadTaskCompletionHandler?) -> URLSessionDownloadTask
        ) -> URLSessionDownloadTask
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
            { receiver, url, completionHandler in
                let callOriginal: (AnyObject, URL, SentryDownloadTaskCompletionHandler?) -> URLSessionDownloadTask = { receiver, url, completionHandler in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (
                            AnyObject,
                            Selector,
                            URL,
                            SentryDownloadTaskCompletionHandler?
                        ) -> URLSessionDownloadTask).self
                    )
                    return original(receiver, method.selector, url, completionHandler)
                }

                guard let typedReceiver = receiver as? Receiver else {
                    SentrySDKLog.error("Unexpected swizzle receiver for \(NSStringFromSelector(method.selector))")
                    return callOriginal(receiver, url, completionHandler)
                }

                return interceptor(typedReceiver, url, completionHandler) { forwardedURL, forwardedCompletionHandler in
                    callOriginal(receiver, forwardedURL, forwardedCompletionHandler)
                }
            } as @convention(block) (
                AnyObject,
                URL,
                SentryDownloadTaskCompletionHandler?
            ) -> URLSessionDownloadTask
        }
    }

    @discardableResult
    static func instanceMethod<Receiver: AnyObject>(
        in classToSwizzle: AnyClass,
        method: SentrySwizzleMethod<Receiver, SentryUploadTaskDataArguments, URLSessionUploadTask>,
        mode: SentrySwizzleMode,
        key: Key,
        interceptor: @escaping (
            Receiver,
            URLRequest,
            Data?,
            SentryDataTaskCompletionHandler?,
            @escaping (URLRequest, Data?, SentryDataTaskCompletionHandler?) -> URLSessionUploadTask
        ) -> URLSessionUploadTask
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
            { receiver, request, data, completionHandler in
                let callOriginal: (AnyObject, URLRequest, Data?, SentryDataTaskCompletionHandler?) -> URLSessionUploadTask = { receiver, request, data, completionHandler in
                    let original = unsafeBitCast(
                        getOriginal(),
                        to: (@convention(c) (
                            AnyObject,
                            Selector,
                            URLRequest,
                            Data?,
                            SentryDataTaskCompletionHandler?
                        ) -> URLSessionUploadTask).self
                    )
                    return original(receiver, method.selector, request, data, completionHandler)
                }

                guard let typedReceiver = receiver as? Receiver else {
                    SentrySDKLog.error("Unexpected swizzle receiver for \(NSStringFromSelector(method.selector))")
                    return callOriginal(receiver, request, data, completionHandler)
                }

                return interceptor(typedReceiver, request, data, completionHandler) { forwardedRequest, forwardedData, forwardedCompletionHandler in
                    callOriginal(receiver, forwardedRequest, forwardedData, forwardedCompletionHandler)
                }
            } as @convention(block) (
                AnyObject,
                URLRequest,
                Data?,
                SentryDataTaskCompletionHandler?
            ) -> URLSessionUploadTask
        }
    }
}
