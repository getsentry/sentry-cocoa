@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryWatchdogTerminationTagsProcessor: NSObject {

    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let scopeTagsStore: SentryScopeTagsPersistentStore

    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeTagsStore: SentryScopeTagsPersistentStore
    ) {
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.scopeTagsStore = scopeTagsStore

        super.init()

        clear()
    }

    public func setTags(_ tags: [String: String]?) {
        SentryLog.debug("Setting tags in background queue: \(tags ?? [:])")
        dispatchQueueWrapper.dispatchAsync { [weak self] in
            guard let strongSelf = self else {
                SentryLog.debug("Can not set tags, reason: reference to tags processor is nil")
                return
            }
            guard let tags = tags else {
                SentryLog.debug("tags is nil, deleting active file.")
                strongSelf.scopeTagsStore.deleteTagsOnDisk()
                return
            }
            strongSelf.scopeTagsStore.writeTagsToDisk(tags: tags)
        }
    }

    public func clear() {
        SentryLog.debug("Deleting tags file in persistent store")
        scopeTagsStore.deleteTagsOnDisk()
    }
}
