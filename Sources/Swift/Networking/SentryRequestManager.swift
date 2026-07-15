import Foundation

/// Manages the queue of HTTP requests the SDK sends to Sentry.
///
/// Named `SentryRequestManager` in Objective-C for backwards compatibility.
@objc(SentryRequestManager) @_spi(Private)
public protocol RequestManager: NSObjectProtocol {

    /// Whether the manager can accept another request right now.
    @objc var isReady: Bool { get }

    /// Enqueues an HTTP request, invoking `completionHandler` when it finishes.
    @objc(addRequest:completionHandler:)
    func add(_ request: URLRequest, completionHandler: SentryRequestOperationFinished?)
}
