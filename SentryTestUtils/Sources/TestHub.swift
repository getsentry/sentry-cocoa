#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import Foundation
import SentryTestUtilsObjC

public class TestHub: SentryTestHubWrapper {

    public convenience init(testClient: TestClient?, scope: Scope?) {
        self.init(client: testClient, andScope: scope)
    }

    public var startSessionInvocations: Int = 0
    public var closeCachedSessionInvocations: Int = 0
    public var endSessionTimestamp: Date?
    public var closeCachedSessionTimestamp: Date?

    public override func startSession() {
        startSessionInvocations += 1
    }
    
    public func setTestSession() {
        wrapper_setSession(SentrySession(releaseName: "Test Release", distinctId: "123"))
    }
    
    public override func closeCachedSession(withTimestamp timestamp: Date?) {
        closeCachedSessionTimestamp = timestamp
        closeCachedSessionInvocations += 1
    }
    
    public override func endSession(withTimestamp timestamp: Date) {
        endSessionTimestamp = timestamp
    }
    
    public var sentFatalEvents = Invocations<Event>()
    public override func captureFatalEvent(_ event: Event) {
        sentFatalEvents.record(event)
    }
    
    public var sentFatalEventsWithScope = Invocations<(event: Event, scope: Scope)>()
    public override func captureFatalEvent(_ event: Event, with scope: Scope) {
        sentFatalEventsWithScope.record((event, scope))
    }
    
    @_spi(Private) public var capturedEventsWithScopes = Invocations<(event: Event, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem])>()
    public override func wrapper_capture(event: Event, scope: Scope, additionalEnvelopeItems: [Any]) -> SentryId {
        guard let additionalEnvelopeItems = additionalEnvelopeItems as? [SentryEnvelopeItem] else {
            return event.eventId
        }
        self.capturedEventsWithScopes.record((event, scope, additionalEnvelopeItems))
        return event.eventId
    }

    @_spi(Private) public var capturedErrorEvents = Invocations<Event>()
    public override func captureErrorEvent(event: Event) -> SentryId {
        self.capturedErrorEvents.record((event))

        return event.eventId
    }

    public var capturedTransactionsWithScope = Invocations<(transaction: [String: Any], scope: Scope)>()
    public override func capture(_ transaction: Transaction, with scope: Scope) {
        capturedTransactionsWithScope.record((transaction.serialize(), scope))
        super.capture(transaction, with: scope)
    }
    
    public var onReplayCapture: (() -> Void)?
    @_spi(Private) public var capturedReplayRecordingVideo = Invocations<(replay: SentryReplayEvent, recording: SentryReplayRecording, video: URL)>()
    
    @_spi(Private) public override func captureReplayEvent(_ replayEvent: Any, replayRecording: Any, video videoURL: URL) {
        capturedReplayRecordingVideo.record((replayEvent as! SentryReplayEvent, replayRecording as! SentryReplayRecording, videoURL))
        onReplayCapture?()
    }
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK    
#if os(iOS) || os(tvOS)
    public var mockReplayId: String?
    public override func getSessionReplayId() -> String? {
        return mockReplayId
    }
#endif
#endif
}
