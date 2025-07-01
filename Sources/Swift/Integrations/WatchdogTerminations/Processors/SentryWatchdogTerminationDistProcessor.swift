@_implementationOnly import _SentryPrivate
import Foundation

class SentryWatchdogTerminationDistProcessor: SentryWatchdogTerminationBaseProcessor<String> {

    private let scopeDistStore: SentryScopeDistPersistentStore

    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeDistStore: SentryScopeDistPersistentStore
    ) {
        self.scopeDistStore = scopeDistStore
        super.init(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            store: scopeDistStore,
            dataTypeName: "dist"
        )
    }

    public func setDist(_ dist: String?) {
        setData(dist) { [weak self] data in
            self?.scopeDistStore.writeDistToDisk(dist: data)
        }
    }
}

// Wrapper to expose the processor to Objective-C
// This is needed because Objective-C has issues with generic types
@objcMembers
public class SentryWatchdogTerminationDistProcessorWrapper: NSObject {
    private let processor: SentryWatchdogTerminationDistProcessor
    
    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeDistStore: SentryScopeDistPersistentStore
    ) {
        self.processor = SentryWatchdogTerminationDistProcessor(withDispatchQueueWrapper: dispatchQueueWrapper, scopeDistStore: scopeDistStore)
    }

    public func setDist(_ dist: String?) {
        processor.setDist(dist)
    }

    public func clear() {
        processor.clear()
    }
} 
