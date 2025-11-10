@_implementationOnly import _SentryPrivate
import Foundation

@objc public final class SentryClient: NSObject {
    let helper: SentryClientInternal
    
    /// Initializes a `SentryClient`. Pass in a dictionary of options.
    /// - Parameter options: Options dictionary
    /// - Returns: An initialized `SentryClient` or `nil` if an error occurred.
    @objc public init?(options: Options) {
        guard let helper = SentryClientInternal(options: options) else {
            return nil
        }
        self.helper = helper
    }
    
    init(helper: SentryClientInternal) {
        self.helper = helper
    }
    
    @objc public  var isEnabled: Bool {
        helper.isEnabled
    }
    
    @objc public var options: Options {
        get {
            // Swift code cannot see ObjC headers that use Swift types, so this needs to use a force cast until SentryClient is completely written in Swift
            // and has this property in the Swift code instead of ObjC.
            // swiftlint:disable force_cast
            return helper.getOptions() as! Options
            // swiftlint:enable force_cast
        }
        set { helper.setOptions(newValue) }
    }
    
    /// Captures a manually created event and sends it to Sentry.
    /// - Parameter event: The event to send to Sentry.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureEvent:) public func capture(event: Event) -> SentryId {
        helper.capture(event: event)
    }

    /// Captures a manually created event and sends it to Sentry.
    /// - Parameters:
    ///   - event: The event to send to Sentry.
    ///   - scope: The scope containing event metadata.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureEvent:withScope:) public func capture(event: Event, scope: Scope) -> SentryId {
        helper.capture(event: event, scope: scope)
    }

    /// Captures an error event and sends it to Sentry.
    /// - Parameter error: The error to send to Sentry.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureError:) public func capture(error: Error) -> SentryId {
        helper.capture(error: error)
    }

    /// Captures an error event and sends it to Sentry.
    /// - Parameters:
    ///   - error: The error to send to Sentry.
    ///   - scope: The scope containing event metadata.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureError:withScope:) public func capture(error: Error, scope: Scope) -> SentryId {
        helper.capture(error: error, scope: scope)
    }

    /// Captures an exception event and sends it to Sentry.
    /// - Parameter exception: The exception to send to Sentry.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureException:) public func capture(exception: NSException) -> SentryId {
        helper.capture(exception: exception)
    }

    /// Captures an exception event and sends it to Sentry.
    /// - Parameters:
    ///   - exception: The exception to send to Sentry.
    ///   - scope: The scope containing event metadata.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureException:withScope:) public func capture(exception: NSException, scope: Scope) -> SentryId {
        helper.capture(exception: exception, scope: scope)
    }

    /// Captures a message event and sends it to Sentry.
    /// - Parameter message: The message to send to Sentry.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureMessage:) public func capture(message: String) -> SentryId {
        helper.capture(message: message)
    }

    /// Captures a message event and sends it to Sentry.
    /// - Parameters:
    ///   - message: The message to send to Sentry.
    ///   - scope: The scope containing event metadata.
    /// - Returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @discardableResult @objc(captureMessage:withScope:) public func capture(message: String, scope: Scope) -> SentryId {
        helper.capture(message: message, scope: scope)
    }

    /// Captures a new-style user feedback and sends it to Sentry.
    /// - Parameters:
    ///   - feedback: The user feedback to send to Sentry.
    ///   - scope: The current scope from which to gather contextual information.
    @objc(captureFeedback:withScope:) public func capture(feedback: SentryFeedback, scope: Scope) {
        helper.captureSerializedFeedback(
          feedback.serialize(),
          withEventId: feedback.eventId.sentryIdString,
          attachments: feedback.attachmentsForEnvelope(),
          scope: scope)
    }

    /// Waits synchronously for the SDK to flush out all queued and cached items for up to the specified timeout in seconds.
    /// If there is no internet connection, the function returns immediately. The SDK doesn't dispose the client or the hub.
    /// - Parameter timeout: The time to wait for the SDK to complete the flush.
    @objc(flush:) public func flush(timeout: TimeInterval) {
        helper.flush(timeout: timeout)
    }

    /// Disables the client and calls flush with `SentryOptions.shutdownTimeInterval`.
    @objc public func close() {
        helper.close()
    }
    
}
