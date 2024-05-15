import Foundation
import Sentry

@objcMembers public class TestNSNotificationCenterWrapper: SentryNSNotificationCenterWrapper {
    
    public var ignoreRemoveObserver = false
    
    public var addObserverInvocations = Invocations<(observer: WeakReference<NSObject>, selector: Selector, name: NSNotification.Name)>()
    public var addObserverInvocationsCount: Int {
        return addObserverInvocations.count
    }

    public override func addObserver(_ observer: NSObject, selector aSelector: Selector, name aName: NSNotification.Name) {
        addObserverInvocations.record((WeakReference(value: observer), aSelector, aName))
    }

    public var removeObserverWithNameInvocations = Invocations< NSNotification.Name>()
    public var removeObserverWithNameInvocationsCount: Int {
        return removeObserverWithNameInvocations.count
    }
    public override func removeObserver(_ observer: NSObject, name aName: NSNotification.Name) {
        removeObserverWithNameInvocations.record(aName)
    }

    /// We don't keep track of the actual objects, because removeObserver
    /// gets often called in dealloc, and we don't want to store an object about to be deallocated
    /// in an array.
    var removeObserverInvocations = Invocations<Void>()
    public var removeObserverInvocationsCount: Int {
        return removeObserverInvocations.count
    }
    public override func removeObserver(_ observer: NSObject) {
        if ignoreRemoveObserver == false {
            removeObserverInvocations.record(Void())
        }
    }
    
    public override func post(_ notification: Notification) {
        addObserverInvocations.invocations
            .filter { $0.2 == notification.name }
            .forEach { observer, selector, _ in
                _ = observer.value?.perform(selector, with: nil)
            }
    }
}
