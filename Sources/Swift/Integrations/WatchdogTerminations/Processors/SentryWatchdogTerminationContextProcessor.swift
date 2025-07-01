@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryWatchdogTerminationContextProcessor: SentryWatchdogTerminationBaseProcessor<[String: [String: Any]]> {

    private let scopeContextStore: SentryScopeContextPersistentStore

    public init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeContextStore: SentryScopeContextPersistentStore
    ) {
        self.scopeContextStore = scopeContextStore
        super.init(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            store: scopeContextStore,
            dataTypeName: "context"
        )
    }

    public func setContext(_ context: [String: [String: Any]]?) {
        setData(context) { [weak self] data in
            self?.scopeContextStore.writeContextToDisk(context: data)
        }
    }
}

// Wrapper to expose the processor to Objective-C
// This is needed because Objective-C has issues with generic types
@objcMembers
public class SentryWatchdogTerminationContextProcessorWrapper: NSObject {
    private let processor: SentryWatchdogTerminationContextProcessor
    
    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeContextStore: SentryScopeContextPersistentStore
    ) {
        self.processor = SentryWatchdogTerminationContextProcessor(withDispatchQueueWrapper: dispatchQueueWrapper, scopeContextStore: scopeContextStore)
    }

    public func setContext(_ context: [String: [String: Any]]?) {
        processor.setContext(context)
    }

    public func clear() {
        processor.clear()
    }
}
