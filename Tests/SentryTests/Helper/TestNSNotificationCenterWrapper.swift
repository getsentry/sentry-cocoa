import Foundation

@objcMembers public class TestNSNotificationCenterWrapper: SentryNSNotificationCenterWrapper {
    var addObserverInvocations = Invocations<(observer: Any, selector: Selector, name: NSNotification.Name)>()
    public var addObserverInvocationsCount: Int {
        return addObserverInvocations.count
    }

    public override func addObserver(_ observer: Any, selector aSelector: Selector, name aName: NSNotification.Name) {
        addObserverInvocations.record((observer, aSelector, aName))
        NotificationCenter.default.addObserver(observer, selector: aSelector, name: aName, object: nil)
    }

    var removeObserverWithNameInvocations = Invocations<(observer: Any, name: NSNotification.Name)>()
    public var removeObserverWithNameInvocationsCount: Int {
        return removeObserverWithNameInvocations.count
    }
    public override func removeObserver(_ observer: Any, name aName: NSNotification.Name) {
        removeObserverWithNameInvocations.record((observer, aName))
        NotificationCenter.default.removeObserver(observer, name: aName, object: nil)
    }

    var removeObserverInvocations = Invocations<Any>()
    public var removeObserverInvocationsCount: Int {
        return removeObserverInvocations.count
    }
    public override func removeObserver(_ observer: Any) {
        removeObserverInvocations.record(observer)
        NotificationCenter.default.removeObserver(observer)
    }
}
