import Foundation

@objc public class TestNSNotificationCenterWrapper: SentryNSNotificationCenterWrapper {
    
    var addObserverInvocations = Invocations<(observer: Any, selector: Selector, name: NSNotification.Name)>()
    public override func addObserver(_ observer: Any, selector aSelector: Selector, name aName: NSNotification.Name) {
        addObserverInvocations.record((observer, aSelector, aName))
    }
    
    var addObserverWithNotificationInvocations = Invocations<(observer: Any, name: NSNotification.Name)>()
    public override func removeObserver(_ observer: Any, name aName: NSNotification.Name) {
        addObserverWithNotificationInvocations.record((observer, aName))
    }
    
    var removeObserverInvocations = Invocations<Any>()
    public override func removeObserver(_ observer: Any) {
        removeObserverInvocations.record(observer)
    }
}
