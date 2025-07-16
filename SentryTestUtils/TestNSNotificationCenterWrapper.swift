import Foundation
@_spi(Private) import Sentry

#if canImport(UIKit)
public typealias CrossPlatformApplication = UIApplication
#else
public typealias CrossPlatformApplication = NSApplication
#endif

@objcMembers public class TestNSNotificationCenterWrapper: NSObject {
    private enum Observer {
        case observerWithObject(WeakReference<NSObject>, Selector, NSNotification.Name?, Any?)
        case observerForKeyPath(WeakReference<NSObject>, String, NSKeyValueObservingOptions, UnsafeMutableRawPointer?)
        case observerWithBlock(WeakReference<NSObject>, NSNotification.Name?, (Notification) -> Void)
    }

    public var ignoreRemoveObserver = false
    public var ignoreAddObserver = false

    private var observers: [Observer] = []

    public var addObserverWithObjectInvocations = Invocations<(
        observer: WeakReference<NSObject>,
        selector: Selector,
        name: NSNotification.Name?,
        object: Any?
    )>()
    public func addObserver(
        _ observer: Any,
        selector aSelector: Selector,
        name aName: NSNotification.Name?,
        object anObject: Any? = nil
    ) {
        if ignoreAddObserver == false {
            addObserverWithObjectInvocations.record((WeakReference(value: observer as! NSObject), aSelector, aName, anObject))
            observers.append(.observerWithObject(WeakReference(value: observer as! NSObject), aSelector, aName, anObject))
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
            observers.append(.observerForKeyPath(WeakReference(value: observer), keyPath, options, context))
        }
    }

    public var addObserverWithBlockInvocations = Invocations<(observer: WeakReference<NSObject>, name: NSNotification.Name?, block: (Notification) -> Void)>()
    public func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @escaping (Notification) -> Void) -> any NSObjectProtocol {
        if ignoreAddObserver == false {
            let observer = NSObject()
            addObserverWithBlockInvocations.record((WeakReference(value: observer), name, block))
            observers.append(.observerWithBlock(WeakReference(value: observer), name, block))
            return observer
        }
        return NSObject()
    }

    /// We don't keep track of the actual objects, because removeObserver
    /// gets often called in dealloc, and we don't want to store an object about to be deallocated
    /// in an array.
    public var removeObserverWithNameAndObjectInvocations = Invocations<(name: NSNotification.Name?, object: Any?)>()
    public func removeObserver(
        _ observer: Any,
        name aName: NSNotification.Name? = nil,
        object anObject: Any? = nil
    ) {
        if ignoreRemoveObserver == false {
            removeObserverWithNameAndObjectInvocations.record((aName, anObject))
            observers.removeAll { item in
                switch item {
                case .observerWithObject(let weakObserver, _, let name, let object):
                    return (weakObserver.value === observer as? NSObject) || 
                           (name == aName && ((object == nil && anObject == nil) || (object as AnyObject === anObject as AnyObject)))
                case .observerWithBlock(let weakObserver, let name, _):
                    return (weakObserver.value === observer as? NSObject) || name == aName
                default:
                    return false
                }
            }
        }
    }

    public var removeObserverForKeyPathWithContextInvocations = Invocations<(keyPath: String, context: UnsafeMutableRawPointer?)>()
    public override func removeObserver(
        _ observer: NSObject,
        forKeyPath keyPath: String,
        context: UnsafeMutableRawPointer?
    ) {
        if ignoreRemoveObserver == false {
            removeObserverForKeyPathWithContextInvocations.record((keyPath, context))
            observers.removeAll { item in
                switch item {
                case .observerForKeyPath(let weakObserver, let path, _, let itemContext):
                    return (weakObserver.value === observer) || 
                           (path == keyPath && itemContext == context)
                default:
                    return false
                }
            }
        }
    }

    public override func removeObserver(
        _ observer: NSObject,
        forKeyPath keyPath: String
    ) {
        removeObserver(observer, forKeyPath: keyPath, context: nil)
    }

    public func post(_ notification: Notification) {
        observers.forEach { observer in
            switch observer {
            case .observerWithObject(let weakObserver, let selector, let name, let object):
                if name == notification.name {
                    let objectsMatch = (object == nil && notification.object == nil) || 
                                     (object as AnyObject? === notification.object as AnyObject?)
                    if objectsMatch {
                        _ = weakObserver.value?.perform(selector, with: notification)
                    }
                }
            case .observerWithBlock(_, let name, let block):
                if name == nil || name == notification.name {
                    block(notification)
                }
            case .observerForKeyPath:
                // Key-value observers don't respond to regular notifications
                break
            }
        }
    }

    // MARK: - Helper Methods

    /// Helper method to clear all observers (useful for testing)
    public func clearAllObservers() {
        observers.removeAll()
        addObserverWithObjectInvocations.removeAll()
        addObserverForKeyPathWithContextInvocations.removeAll()
        addObserverWithBlockInvocations.removeAll()
        removeObserverWithNameAndObjectInvocations.removeAll()
        removeObserverForKeyPathWithContextInvocations.removeAll()
    }

    /// Helper method to get count of active observers
    public var observerCount: Int {
        return observers.count
    }
}

@_spi(Private) extension TestNSNotificationCenterWrapper: SentryNSNotificationCenterWrapper {
}
