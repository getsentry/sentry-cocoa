import Foundation

@objcMembers public class TestNSNotificationCenterWrapper: SentryNSNotificationCenterWrapper {
    public var addObserverInvocations = Invocations<(observer: Any, selector: Selector, name: NSNotification.Name)>()
    public var addObserverInvocationsCount: Int {
        return addObserverInvocations.count
    }

    public override func addObserver(_ observer: Any, selector aSelector: Selector, name aName: NSNotification.Name) {
        addObserverInvocations.record((observer, aSelector, aName))
    }

    public var removeObserverWithNameInvocations = Invocations<(observer: Any, name: NSNotification.Name)>()
    public var removeObserverWithNameInvocationsCount: Int {
        return removeObserverWithNameInvocations.count
    }
    public override func removeObserver(_ observer: Any, name aName: NSNotification.Name) {
        removeObserverWithNameInvocations.record((observer, aName))
    }

    public var removeObserverInvocations = Invocations<Any>()
    public var removeObserverInvocationsCount: Int {
        return removeObserverInvocations.count
    }
    public override func removeObserver(_ observer: Any) {
        removeObserverInvocations.record(observer)
    }
}
