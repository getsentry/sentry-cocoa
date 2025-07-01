@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
@_spi(Private) public class SentryWatchdogTerminationBaseProcessor<T>: NSObject {
    
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let store: SentryScopeBasePersistentStore
    private let dataTypeName: String
    
    init(
        withDispatchQueueWrapper dispatchQueueWrapper: SentryDispatchQueueWrapper,
        store: SentryScopeBasePersistentStore,
        dataTypeName: String
    ) {
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.store = store
        self.dataTypeName = dataTypeName
        
        super.init()
        
        clear()
    }
    
    func setData(_ data: T?, writeAction: @escaping (T) -> Void) {
        SentryLog.debug("Setting \(dataTypeName) in background queue: \(String(describing: data))")
        let name = dataTypeName
        dispatchQueueWrapper.dispatchAsync { [weak self] in
            guard let strongSelf = self else {
                SentryLog.debug("Can not set \(name), reason: reference to \(name) processor is nil")
                return
            }
            guard let data = data else {
                SentryLog.debug("\(strongSelf.dataTypeName) is nil, deleting active file.")
                strongSelf.store.deleteStateOnDisk()
                return
            }
            writeAction(data)
        }
    }
    
    public func clear() {
        SentryLog.debug("Deleting \(dataTypeName) file in persistent store")
        store.deleteStateOnDisk()
    }
}
