@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryWatchdogTerminationTagsProcessor: SentryWatchdogTerminationBaseProcessor<[String: String]> {

    private let scopeTagsStore: SentryScopeTagsPersistentStore

    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeTagsStore: SentryScopeTagsPersistentStore
    ) {
        self.scopeTagsStore = scopeTagsStore
        super.init(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            store: scopeTagsStore,
            dataTypeName: "tags"
        )
    }

    public func setTags(_ tags: [String: String]?) {
        setData(tags) { [weak self] data in
            self?.scopeTagsStore.writeTagsToDisk(tags: data)
        }
    }
}

// Wrapper to expose the processor to Objective-C
// This is needed because Objective-C has issues with generic types
@objcMembers
public class SentryWatchdogTerminationTagsProcessorWrapper: NSObject {
    private let processor: SentryWatchdogTerminationTagsProcessor
    
    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeTagsStore: SentryScopeTagsPersistentStore
    ) {
        self.processor = SentryWatchdogTerminationTagsProcessor(withDispatchQueueWrapper: dispatchQueueWrapper, scopeTagsStore: scopeTagsStore)
    }

    public func setTags(_ tags: [String: String]?) {
        processor.setTags(tags)
    }

    public func clear() {
        processor.clear()
    }
}
