@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryWatchdogTerminationEnvironmentProcessor: SentryWatchdogTerminationBaseProcessor<String> {

    private let scopeEnvironmentStore: SentryScopeEnvironmentPersistentStore

    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeEnvironmentStore: SentryScopeEnvironmentPersistentStore
    ) {
        self.scopeEnvironmentStore = scopeEnvironmentStore
        super.init(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            store: scopeEnvironmentStore,
            dataTypeName: "environment"
        )
    }

    public func setEnvironment(_ environment: String?) {
        setData(environment) { [weak self] data in
            self?.scopeEnvironmentStore.writeEnvironmentToDisk(environment: data)
        }
    }
}

// Wrapper to expose the processor to Objective-C
// This is needed because Objective-C has issues with generic types
@objcMembers
public class SentryWatchdogTerminationEnvironmentProcessorWrapper: NSObject {
    private let processor: SentryWatchdogTerminationEnvironmentProcessor
    
    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeEnvironmentStore: SentryScopeEnvironmentPersistentStore
    ) {
        self.processor = SentryWatchdogTerminationEnvironmentProcessor(withDispatchQueueWrapper: dispatchQueueWrapper, scopeEnvironmentStore: scopeEnvironmentStore)
    }

    public func setEnvironment(_ environment: String?) {
        processor.setEnvironment(environment)
    }

    public func clear() {
        processor.clear()
    }
} 
