@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryWatchdogTerminationUserProcessor: SentryWatchdogTerminationBaseProcessor<User> {

    private let scopeUserStore: SentryScopeUserPersistentStore

    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeUserStore: SentryScopeUserPersistentStore
    ) {
        self.scopeUserStore = scopeUserStore
        super.init(
            withDispatchQueueWrapper: dispatchQueueWrapper,
            store: scopeUserStore,
            dataTypeName: "user"
        )
    }

    public func setUser(_ user: User?) {
        setData(user) { [weak self] data in
            self?.scopeUserStore.writeUserToDisk(user: data)
        }
    }
}

// Wrapper to expose the processor to Objective-C
// This is needed because Objective-C has issues with generic types
@objcMembers
public class SentryWatchdogTerminationUserProcessorWrapper: NSObject {
    private let processor: SentryWatchdogTerminationUserProcessor
    
    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeUserStore: SentryScopeUserPersistentStore
    ) {
        self.processor = SentryWatchdogTerminationUserProcessor(withDispatchQueueWrapper: dispatchQueueWrapper, scopeUserStore: scopeUserStore)
    }

    public func setUser(_ user: User?) {
        processor.setUser(user)
    }

    public func clear() {
        processor.clear()
    }
}
