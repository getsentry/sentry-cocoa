@_implementationOnly import _SentryPrivate
import Foundation

class SentryWatchdogTerminationFingerprintProcessor: SentryWatchdogTerminationBaseProcessor<[String]> {

    private let scopeFingerprintStore: SentryScopeFingerprintPersistentStore

    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeFingerprintStore: SentryScopeFingerprintPersistentStore
    ) {
        self.scopeFingerprintStore = scopeFingerprintStore
        super.init(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            store: scopeFingerprintStore,
            dataTypeName: "fingerprint"
        )
    }

    public func setFingerprint(_ fingerprint: [String]?) {
        setData(fingerprint) { [weak self] data in
            self?.scopeFingerprintStore.writeFingerprintToDisk(fingerprint: data)
        }
    }
}

// Wrapper to expose the processor to Objective-C
// This is needed because Objective-C has issues with generic types
@objcMembers
public class SentryWatchdogTerminationFingerprintProcessorWrapper: NSObject {
    private let processor: SentryWatchdogTerminationFingerprintProcessor
    
    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeFingerprintStore: SentryScopeFingerprintPersistentStore
    ) {
        self.processor = SentryWatchdogTerminationFingerprintProcessor(withDispatchQueueWrapper: dispatchQueueWrapper, scopeFingerprintStore: scopeFingerprintStore)
    }

    public func setFingerprint(_ fingerprint: [String]?) {
        processor.setFingerprint(fingerprint)
    }

    public func clear() {
        processor.clear()
    }
} 
