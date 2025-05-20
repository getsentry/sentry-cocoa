@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
class SentryWatchdogTerminationContextProcessor: NSObject {

    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let scopeSerialization: SentryScopeContextPersistentStore

    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        scopeSerialization: SentryScopeContextPersistentStore
    ) {
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.scopeSerialization = scopeSerialization

        super.init()

        clear()
    }

    func setContext(_ context: [String: [String: Any]]?) {
        SentryLog.debug("Setting context in background queue: \(context ?? [:])")
        dispatchQueueWrapper.dispatchAsync { [weak self] in
            guard let strongSelf = self else {
                SentryLog.debug("Can not set context, reason: reference to context processor is nil")
                return
            }
            guard let context = context else {
                SentryLog.debug("Context is nil, deleting active file.")
                strongSelf.clear()
                return
            }
            strongSelf.scopeSerialization.writeContextToDisk(context: context)
        }
    }

    func clear() {
        let path = scopeSerialization.contextFileURL.path
        SentryLog.debug("Deleting context file at path: \(path)")

        let fm = FileManager.default
        do {
            if fm.fileExists(atPath: path) {
                try fm.removeItem(atPath: path)
            }
        } catch {
            SentryLog.error("Failed to delete context file at path: \(path), reason: \(error)")
        }
    }
}
