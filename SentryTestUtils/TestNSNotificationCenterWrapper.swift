import Foundation
import Sentry

@objcMembers public class TestNSNotificationCenterWrapper: SentryNSNotificationCenterWrapper {
    
    public var ignoreRemoveObserver = false
    public var ignoreAddObserver = false
    
    public var addObserverInvocations = Invocations<(
        observer: WeakReference<NSObject>,
        selector: Selector,
        name: NSNotification.Name
    )>()
    public override func addObserver(
        _ observer: NSObject,
        selector aSelector: Selector,
        name aName: NSNotification.Name
    ) {
        if ignoreAddObserver == false {
            addObserverInvocations.record((WeakReference(value: observer), aSelector, aName))
        }
    }

    public var addObserverWithObjectInvocations = Invocations<(
        observer: WeakReference<NSObject>,
        selector: Selector,
        name: NSNotification.Name,
        object: Any?
    )>()
    public override func addObserver(
        _ observer: NSObject,
        selector aSelector: Selector,
        name aName: NSNotification.Name,
        object anObject: Any?
    ) {
        if ignoreAddObserver == false {
            addObserverWithObjectInvocations.record((WeakReference(value: observer), aSelector, aName, anObject))
        }
    }

    public var addObserverForKeyPathWithContextInvocations = Invocations<(
        observer: WeakReference<NSObject>,
        keyPath: String,
        options: NSKeyValueObservingOptions,
        context: UnsafeMutableRawPointer?
    )>()
    public override func addObserver(
        _ observer: NSObject,
        forKeyPath keyPath: String,
        options: NSKeyValueObservingOptions = [],
        context: UnsafeMutableRawPointer?
    ) {
        if ignoreAddObserver == false {
            addObserverForKeyPathWithContextInvocations.record((WeakReference(value: observer), keyPath, options, context))
        }
    }

    public var addObserverWithBlockInvocations = Invocations<(observer: WeakReference<NSObject>, name: NSNotification.Name?, block: (Notification) -> Void)>()
    public override func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @escaping (Notification) -> Void) -> any NSObjectProtocol {
        let observer = NSObject()
        addObserverWithBlockInvocations.record((WeakReference(value: observer), name, block))
        return observer
    }

    public var removeObserverWithNameInvocations = Invocations< NSNotification.Name>()
    public override func removeObserver(_ observer: any NSObjectProtocol, name aName: NSNotification.Name) {
        removeObserverWithNameInvocations.record(aName)
    }

    /// We don't keep track of the actual objects, because removeObserver
    /// gets often called in dealloc, and we don't want to store an object about to be deallocated
    /// in an array.
    public var removeObserverInvocations = Invocations<Void>()
    public override func removeObserver(_ observer: any NSObjectProtocol) {
        if ignoreRemoveObserver == false {
            removeObserverInvocations.record(Void())
        }
    }
    
    public override func post(_ notification: Notification) {
        addObserverInvocations.invocations
            .filter { $0.name == notification.name }
            .forEach { observer, selector, _ in
                _ = observer.value?.perform(selector, with: notification.object)
            }
        addObserverWithObjectInvocations.invocations
            .filter { $0.name == notification.name }
            .filter { ($0.object == nil && notification.object == nil) || $0.object as AnyObject === notification.object as AnyObject }
            .forEach { observer, selector, _, _ in
                _ = observer.value?.perform(selector, with: notification)
            }
        addObserverWithBlockInvocations.invocations.forEach { _, name, block in
            if let name = name {
                block(Notification(name: name))
            }
        }
    }
}
