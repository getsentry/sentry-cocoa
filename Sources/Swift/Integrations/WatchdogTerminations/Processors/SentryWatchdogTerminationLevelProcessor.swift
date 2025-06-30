@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryWatchdogTerminationLevelProcessor: NSObject {

    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let scopeLevelStore: SentryScopeLevelPersistentStore

    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeLevelStore: SentryScopeLevelPersistentStore
    ) {
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.scopeLevelStore = scopeLevelStore

        super.init()

        clear()
    }

    public func setLevel(_ level: NSNumber?) {
        SentryLog.debug("Setting level in background queue: \(level?.uintValue ?? 0)")
        dispatchQueueWrapper.dispatchAsync { [weak self] in
            guard let strongSelf = self else {
                SentryLog.debug("Can not set level, reason: reference to level processor is nil")
                return
            }
            guard let levelRaw = level,
                  let level = SentryLevel(rawValue: levelRaw.uintValue) else {
                SentryLog.debug("level is nil, deleting active file.")
                strongSelf.scopeLevelStore.deleteLevelOnDisk()
                return
            }
            strongSelf.scopeLevelStore.writeLevelToDisk(level: level)
        }
    }

    public func clear() {
        SentryLog.debug("Deleting level file in persistent store")
        scopeLevelStore.deleteLevelOnDisk()
    }
}
