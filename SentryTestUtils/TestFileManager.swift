import _SentryPrivate
import Foundation
@_spi(Private) import Sentry

public class TestFileManager: SentryFileManager {
    var timestampLastInForeground: Date?
    var readTimestampLastInForegroundInvocations: Int = 0
    var storeTimestampLastInForegroundInvocations: Int = 0
    var deleteTimestampLastInForegroundInvocations: Int = 0

    public var storeEnvelopeInvocations = Invocations<SentryEnvelope>()
    public var storeEnvelopePath: String?
    public var storeEnvelopePathNil: Bool = false
    
    public init(options: Options) throws {
        try super.init(options: options, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
    }
    
    public override func store(_ envelope: SentryEnvelope) -> String? {
        storeEnvelopeInvocations.record(envelope)
        if storeEnvelopePathNil {
            return nil
        } else {
            return storeEnvelopePath ?? super.store(envelope)
        }
    }
    
    public var deleteOldEnvelopeItemsInvocations = Invocations<Void>()
    public override func deleteOldEnvelopeItems() {
        deleteOldEnvelopeItemsInvocations.record(Void())
    }

    public override func readTimestampLastInForeground() -> Date? {
        readTimestampLastInForegroundInvocations += 1
        return timestampLastInForeground
    }

    public override func storeTimestampLast(inForeground: Date) {
        storeTimestampLastInForegroundInvocations += 1
        timestampLastInForeground = inForeground
    }

    public override func deleteTimestampLastInForeground() {
        deleteTimestampLastInForegroundInvocations += 1
        timestampLastInForeground = nil
    }
    
    var readAppStateInvocations = Invocations<Void>()
    @_spi(Private) public override func readAppState() -> SentryAppState? {
        readAppStateInvocations.record(Void())
        return nil
    }

    var appState: SentryAppState?
    public var readPreviousAppStateInvocations = Invocations<Void>()
    @_spi(Private) public override func readPreviousAppState() -> SentryAppState? {
        readPreviousAppStateInvocations.record(Void())
        return appState
    }
}
