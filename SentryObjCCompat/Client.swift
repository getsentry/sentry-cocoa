internal import SentrySwift
import Foundation

/// The Sentry client is responsible for capturing events and sending them to Sentry.
@objc(SOCSentryClient)
public final class Client: NSObject {
    internal let wrapped: SentrySwift.SentryClient

    internal init(_ wrapped: SentrySwift.SentryClient) {
        self.wrapped = wrapped
        super.init()
    }

    @objc public init?(options: Options) {
        guard let underlying = SentrySwift.SentryClient(options: options.wrapped) else {
            return nil
        }
        self.wrapped = underlying
        super.init()
    }

    @objc public var isEnabled: Bool { wrapped.isEnabled }

    @objc public var options: Options {
        get { Options(wrapped.options) }
        set { wrapped.options = newValue.wrapped }
    }

    @objc(captureEvent:)
    @discardableResult
    public func capture(event: Event) -> SentryId {
        SentryId(wrapped.capture(event: event.wrapped))
    }

    @objc(captureEvent:withScope:)
    @discardableResult
    public func capture(event: Event, scope: Scope) -> SentryId {
        SentryId(wrapped.capture(event: event.wrapped, scope: scope.wrapped))
    }

    @objc(captureError:)
    @discardableResult
    public func capture(error: Error) -> SentryId {
        SentryId(wrapped.capture(error: error))
    }

    @objc(captureError:withScope:)
    @discardableResult
    public func capture(error: Error, scope: Scope) -> SentryId {
        SentryId(wrapped.capture(error: error, scope: scope.wrapped))
    }

    @objc(captureException:)
    @discardableResult
    public func capture(exception: NSException) -> SentryId {
        SentryId(wrapped.capture(exception: exception))
    }

    @objc(captureException:withScope:)
    @discardableResult
    public func capture(exception: NSException, scope: Scope) -> SentryId {
        SentryId(wrapped.capture(exception: exception, scope: scope.wrapped))
    }

    @objc(captureMessage:)
    @discardableResult
    public func capture(message: String) -> SentryId {
        SentryId(wrapped.capture(message: message))
    }

    @objc(captureMessage:withScope:)
    @discardableResult
    public func capture(message: String, scope: Scope) -> SentryId {
        SentryId(wrapped.capture(message: message, scope: scope.wrapped))
    }

    @objc(captureFeedback:withScope:)
    public func capture(feedback: Feedback, scope: Scope) {
        wrapped.capture(feedback: feedback.wrapped, scope: scope.wrapped)
    }

    @objc(flush:)
    public func flush(timeout: TimeInterval) {
        wrapped.flush(timeout: timeout)
    }

    @objc public func close() {
        wrapped.close()
    }
}
