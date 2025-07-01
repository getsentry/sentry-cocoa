@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryWatchdogTerminationExtrasProcessor: SentryWatchdogTerminationBaseProcessor<[String: Any]> {

    private let scopeExtrasStore: SentryScopeExtrasPersistentStore

    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeExtrasStore: SentryScopeExtrasPersistentStore
    ) {
        self.scopeExtrasStore = scopeExtrasStore
        super.init(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            store: scopeExtrasStore,
            dataTypeName: "extras"
        )
    }

    public func setExtras(_ extras: [String: Any]?) {
        setData(extras) { [weak self] data in
            self?.scopeExtrasStore.writeExtrasToDisk(extras: data)
        }
    }
}

// Wrapper to expose the processor to Objective-C
// This is needed because Objective-C has issues with generic types
@objcMembers
public class SentryWatchdogTerminationExtrasProcessorWrapper: NSObject {
    private let processor: SentryWatchdogTerminationExtrasProcessor
    
    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeExtrasStore: SentryScopeExtrasPersistentStore
    ) {
        self.processor = SentryWatchdogTerminationExtrasProcessor(withDispatchQueueWrapper: dispatchQueueWrapper, scopeExtrasStore: scopeExtrasStore)
    }

    public func setExtras(_ extras: [String: Any]?) {
        processor.setExtras(extras)
    }

    public func clear() {
        processor.clear()
    }
} 
