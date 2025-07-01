@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryWatchdogTerminationLevelProcessor: SentryWatchdogTerminationBaseProcessor<NSNumber> {

    private let scopeLevelStore: SentryScopeLevelPersistentStore

    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeLevelStore: SentryScopeLevelPersistentStore
    ) {
        self.scopeLevelStore = scopeLevelStore
        super.init(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            store: scopeLevelStore,
            dataTypeName: "level"
        )
    }

    public func setLevel(_ level: NSNumber?) {
        // Validate the level before processing
        let validatedLevel: NSNumber?
        if let levelRaw = level,
           SentryLevel(rawValue: levelRaw.uintValue) != nil {
            validatedLevel = level
        } else {
            validatedLevel = nil
        }
        
        setData(validatedLevel) { [weak self] level in
            guard let sentryLevel = SentryLevel(rawValue: level.uintValue) else { return }
            self?.scopeLevelStore.writeLevelToDisk(level: sentryLevel)
        }
    }
}

// Wrapper to expose the processor to Objective-C
// This is needed because Objective-C has issues with generic types
@objcMembers
public class SentryWatchdogTerminationLevelProcessorWrapper: NSObject {
    private let processor: SentryWatchdogTerminationLevelProcessor
    
    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeLevelStore: SentryScopeLevelPersistentStore
    ) {
        self.processor = SentryWatchdogTerminationLevelProcessor(withDispatchQueueWrapper: dispatchQueueWrapper, scopeLevelStore: scopeLevelStore)
    }

    public func setLevel(_ level: NSNumber?) {
        processor.setLevel(level)
    }

    public func clear() {
        processor.clear()
    }
}
