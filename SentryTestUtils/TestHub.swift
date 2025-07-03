import _SentryPrivate
import Foundation
@_spi(Private) @testable import Sentry

public class TestHub: SentryHub {

    public var startSessionInvocations: Int = 0
    public var closeCachedSessionInvocations: Int = 0
    public var endSessionTimestamp: Date?
    public var closeCachedSessionTimestamp: Date?

    public override func startSession() {
        startSessionInvocations += 1
    }
    
    public func setTestSession() {
        self.session = SentrySession(releaseName: "Test Release", distinctId: "123")
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
    
    public var capturedEventsWithScopes = Invocations<(event: Event, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem])>()
    public override func capture(event: Event, scope: Scope, additionalEnvelopeItems: [SentryEnvelopeItem]) -> SentryId {
        
        self.capturedEventsWithScopes.record((event, scope, additionalEnvelopeItems))
        
        return event.eventId
    }

    public var capturedTransactionsWithScope = Invocations<(transaction: [String: Any], scope: Scope)>()
    public override func capture(_ transaction: Transaction, with scope: Scope) {
        capturedTransactionsWithScope.record((transaction.serialize(), scope))
        super.capture(transaction, with: scope)
    }
    
    public var onReplayCapture: (() -> Void)?
    @_spi(Private) public var capturedReplayRecordingVideo = Invocations<(replay: SentryReplayEvent, recording: SentryReplayRecording, video: URL)>()
    @_spi(Private) public override func capture(_ replayEvent: SentryReplayEvent, replayRecording: SentryReplayRecording, video videoURL: URL) {
        capturedReplayRecordingVideo.record((replayEvent, replayRecording, videoURL))
        onReplayCapture?()
    }
    
    @_spi(Private) public var captureLogInvocations = Invocations<(log: SentryLog, scope: Scope)>()
    @_spi(Private) public override func capture(log: SentryLog) {
        captureLogInvocations.record((log, self.scope))
    }
}
