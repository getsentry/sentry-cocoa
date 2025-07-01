@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryWatchdogTerminationTraceContextProcessor: SentryWatchdogTerminationBaseProcessor<[String: Any]> {

    private let scopeTraceContextStore: SentryScopeTraceContextPersistentStore

    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeTraceContextStore: SentryScopeTraceContextPersistentStore
    ) {
        self.scopeTraceContextStore = scopeTraceContextStore
        super.init(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            store: scopeTraceContextStore,
            dataTypeName: "traceContext"
        )
    }

    public func setTraceContext(_ traceContext: [String: Any]?) {
        setData(traceContext) { [weak self] data in
            self?.scopeTraceContextStore.writeTraceContextToDisk(traceContext: data)
        }
    }
}

// Wrapper to expose the processor to Objective-C
// This is needed because Objective-C has issues with generic types
@objcMembers
public class SentryWatchdogTerminationTraceContextProcessorWrapper: NSObject {
    private let processor: SentryWatchdogTerminationTraceContextProcessor
    
    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeTraceContextStore: SentryScopeTraceContextPersistentStore
    ) {
        self.processor = SentryWatchdogTerminationTraceContextProcessor(withDispatchQueueWrapper: dispatchQueueWrapper, scopeTraceContextStore: scopeTraceContextStore)
    }

    public func setTraceContext(_ traceContext: [String: Any]?) {
        processor.setTraceContext(traceContext)
    }

    public func clear() {
        processor.clear()
    }
} 
