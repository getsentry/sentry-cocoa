@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryWatchdogTerminationUserProcessor: NSObject {

    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let scopeUserStore: SentryScopeUserPersistentStore

    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeUserStore: SentryScopeUserPersistentStore
    ) {
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.scopeUserStore = scopeUserStore

        super.init()

        clear()
    }

    public func setUser(_ user: User?) {
        SentryLog.debug("Setting user in background queue: \(String(describing: user))")
        dispatchQueueWrapper.dispatchAsync { [weak self] in
            guard let strongSelf = self else {
                SentryLog.debug("Can not set User, reason: reference to User processor is nil")
                return
            }
            guard let user = user else {
                SentryLog.debug("User is nil, deleting active file.")
                strongSelf.scopeUserStore.deleteUserOnDisk()
                return
            }
            strongSelf.scopeUserStore.writeUserToDisk(user: user)
        }
    }

    public func clear() {
        SentryLog.debug("Deleting user file in persistent store")
        scopeUserStore.deleteUserOnDisk()
    }
}
