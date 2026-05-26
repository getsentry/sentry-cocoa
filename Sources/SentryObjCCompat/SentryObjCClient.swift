// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

public final class SentryObjCClient: NSObject {
    internal let wrapped: SentryClient

    internal init(_ wrapped: SentryClient) {
        self.wrapped = wrapped
    }

    @objc public init?(options: SentryObjCOptions) {
        guard let client = SentryClient(options: options.wrapped) else {
            return nil
        }
        self.wrapped = client
    }

    @objc public var isEnabled: Bool {
        wrapped.isEnabled
    }

    @objc public var options: SentryObjCOptions {
        get { SentryObjCOptions(wrapped.options) }
        set { wrapped.options = newValue.wrapped }
    }

    @discardableResult
    @objc(captureEvent:) public func capture(event: SentryObjCEvent) -> SentryObjCId {
        SentryObjCId(wrapped.capture(event: event.wrapped))
    }

    @discardableResult
    @objc(captureEvent:withScope:) public func capture(event: SentryObjCEvent, scope: SentryObjCScope) -> SentryObjCId {
        SentryObjCId(wrapped.capture(event: event.wrapped, scope: scope.wrapped))
    }

    @discardableResult
    @objc(captureError:) public func capture(error: NSError) -> SentryObjCId {
        SentryObjCId(wrapped.capture(error: error))
    }

    @discardableResult
    @objc(captureError:withScope:) public func capture(error: NSError, scope: SentryObjCScope) -> SentryObjCId {
        SentryObjCId(wrapped.capture(error: error, scope: scope.wrapped))
    }

    @discardableResult
    @objc(captureException:) public func capture(exception: NSException) -> SentryObjCId {
        SentryObjCId(wrapped.capture(exception: exception))
    }

    @discardableResult
    @objc(captureException:withScope:) public func capture(exception: NSException, scope: SentryObjCScope) -> SentryObjCId {
        SentryObjCId(wrapped.capture(exception: exception, scope: scope.wrapped))
    }

    @discardableResult
    @objc(captureMessage:) public func capture(message: String) -> SentryObjCId {
        SentryObjCId(wrapped.capture(message: message))
    }

    @discardableResult
    @objc(captureMessage:withScope:) public func capture(message: String, scope: SentryObjCScope) -> SentryObjCId {
        SentryObjCId(wrapped.capture(message: message, scope: scope.wrapped))
    }

    @objc(captureFeedback:withScope:) public func capture(feedback: SentryObjCFeedback, scope: SentryObjCScope) {
        wrapped.capture(feedback: feedback.wrapped, scope: scope.wrapped)
    }

    @objc(flush:) public func flush(timeout: TimeInterval) {
        wrapped.flush(timeout: timeout)
    }

    @objc public func close() {
        wrapped.close()
    }
}

// swiftlint:enable missing_docs
