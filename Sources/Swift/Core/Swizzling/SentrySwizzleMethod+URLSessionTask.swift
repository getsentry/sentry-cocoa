import Foundation

extension SentrySwizzleMethod where Receiver: URLSessionTask, Arguments == Void, Result == Void {
    /// Describes the method signature of `URLSessionTask.resume()`.
    ///
    /// - Parameter receiver: The type of task object receiving the Objective-C message and passed to
    ///   the interceptor as its first argument.
    /// - Returns: A descriptor containing the `resume` selector and corresponding Objective-C runtime
    ///   signature.
    /// - SeeAlso: `URLSessionTask.resume()`
    static func urlSessionTaskResume(_ receiver: Receiver.Type) -> Self {
        .init(
            selector: #selector(URLSessionTask.resume),
            receiver: receiver,
            signature: .init(returnType: .void, arguments: [.object, .selector])
        )
    }
}

extension SentrySwizzleMethod where Arguments == URLSessionTask.State, Result == Void {
    /// Describes the method signature of `URLSessionTask.setState(_:)`, a private API accepting a `URLSessionTask.State` value.
    ///
    ///
    /// - Parameter receiver: The type of task object receiving the Objective-C message and passed to
    ///   the interceptor as its first argument.
    /// - Returns: A descriptor containing the private `setState:` selector and corresponding
    ///   Objective-C runtime signature.
    static func urlSessionTaskState(_ receiver: Receiver.Type) -> Self {
        .init(
            selector: NSSelectorFromString("setState:"),
            receiver: receiver,
            signature: .init(
                returnType: .void,
                arguments: [.object, .selector, .signedInteger(MemoryLayout<Int>.size)]
            )
        )
    }
}

/// The Objective-C block convention used by URL session data task completion handlers.
typealias SentryDataTaskCompletionHandler = @convention(block) (Data?, URLResponse?, Error?) -> Void

/// The explicit arguments of `dataTask(with:completionHandler:)` when called with a request.
typealias SentryDataTaskRequestArguments = (URLRequest, SentryDataTaskCompletionHandler?)

/// The explicit arguments of `dataTask(with:completionHandler:)` when called with a URL.
typealias SentryDataTaskURLArguments = (URL, SentryDataTaskCompletionHandler?)

extension SentrySwizzleMethod where Arguments == SentryDataTaskRequestArguments, Result == URLSessionDataTask {
    /// Describes the method signature of `URLSession.dataTask(with:completionHandler:)` accepting a `URLRequest`.
    ///
    /// - Parameter receiver: The type of URL session object receiving the Objective-C message and
    ///   passed to the interceptor as its first argument.
    /// - Returns: A descriptor containing the request overload's selector and corresponding
    ///   Objective-C runtime signature.
    /// - SeeAlso: `URLSession.dataTask(with:completionHandler:)` accepting a `URLRequest`.
    static func urlSessionDataTaskWithRequest(_ receiver: Receiver.Type) -> Self {
        .init(
            selector: #selector(URLSession.dataTask(with:completionHandler:)
                as (URLSession) -> (URLRequest, @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask),
            receiver: receiver,
            signature: .init(
                returnType: .object,
                arguments: [.object, .selector, .object, .block]
            )
        )
    }
}

extension SentrySwizzleMethod where Arguments == SentryDataTaskURLArguments, Result == URLSessionDataTask {
    /// Describes the method signature of `URLSession.dataTask(with:completionHandler:)` accepting a `URL`.
    ///
    /// - Parameter receiver: The type of URL session object receiving the Objective-C message and
    ///   passed to the interceptor as its first argument.
    /// - Returns: A descriptor containing the URL overload's selector and corresponding Objective-C
    ///   runtime signature.
    /// - SeeAlso: `URLSession.dataTask(with:completionHandler:)` accepting a `URL`.
    static func urlSessionDataTaskWithURL(_ receiver: Receiver.Type) -> Self {
        .init(
            selector: #selector(URLSession.dataTask(with:completionHandler:)
                as (URLSession) -> (URL, @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask),
            receiver: receiver,
            signature: .init(
                returnType: .object,
                arguments: [.object, .selector, .object, .block]
            )
        )
    }
}
