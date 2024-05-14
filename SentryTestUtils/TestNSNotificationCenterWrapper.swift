import Foundation
import Sentry

@objcMembers public class TestNSNotificationCenterWrapper: SentryNSNotificationCenterWrapper {
    
    public var ignoreRemoveObserver = false
    
    public var addObserverInvocations = Invocations<(observer: NSObject, selector: Selector, name: NSNotification.Name)>()
    public var addObserverInvocationsCount: Int {
        return addObserverInvocations.count
    }

    public override func addObserver(_ observer: NSObject, selector aSelector: Selector, name aName: NSNotification.Name) {
        addObserverInvocations.record((observer, aSelector, aName))
    }

    public var removeObserverWithNameInvocations = Invocations<(observer: NSObject, name: NSNotification.Name)>()
    public var removeObserverWithNameInvocationsCount: Int {
        return removeObserverWithNameInvocations.count
    }
    public override func removeObserver(_ observer: NSObject, name aName: NSNotification.Name) {
        removeObserverWithNameInvocations.record((observer, aName))
    }

    var removeObserverInvocations = Invocations<NSObject>()
    public var removeObserverInvocationsCount: Int {
        return removeObserverInvocations.count
    }
    public override func removeObserver(_ observer: NSObject) {
        if ignoreRemoveObserver == false {
            removeObserverInvocations.record(observer)
        }
    }
    
    public override func post(_ notification: Notification) {
        addObserverInvocations.invocations
            .filter { $0.2 == notification.name }
            .forEach { observer, selector, _ in
                _ = observer.perform(selector, with: nil)
            }
    }
}
