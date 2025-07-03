import Foundation
import Sentry

#if canImport(UIKit)
public typealias CrossPlatformApplication = UIApplication
#else
public typealias CrossPlatformApplication = NSApplication
#endif

@objcMembers public class TestNSNotificationCenterWrapper: SentryNSNotificationCenterWrapper {
    private enum Observer {
        case observer(WeakReference<NSObject>, Selector, NSNotification.Name)
        case observerWithObject(WeakReference<NSObject>, Selector, NSNotification.Name, Any?)
        case observerForKeyPath(WeakReference<NSObject>, String, NSKeyValueObservingOptions, UnsafeMutableRawPointer?)
        case observerWithBlock(WeakReference<NSObject>, NSNotification.Name?, (Notification) -> Void)
    }

    public var ignoreRemoveObserver = false
    public var ignoreAddObserver = false

    private var observers: [Observer] = []

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
            observers.append(.observer(WeakReference(value: observer), aSelector, aName))
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
            observers.append(.observerWithObject(WeakReference(value: observer), aSelector, aName, anObject))
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
    public override func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @escaping (Notification) -> Void) -> any NSObjectProtocol {
        if ignoreAddObserver == false {
            let observer = NSObject()
            addObserverWithBlockInvocations.record((WeakReference(value: observer), name, block))
            observers.append(.observerWithBlock(WeakReference(value: observer), name, block))
            return observer
        }
        return NSObject()
    }

    public var removeObserverWithNameInvocations = Invocations<NSNotification.Name>()
    public override func removeObserver(_ observer: any NSObjectProtocol, name aName: NSNotification.Name) {
        if ignoreRemoveObserver == false {
            removeObserverWithNameInvocations.record(aName)
            observers.removeAll { item in
                switch item {
                case .observer(let weakObserver, _, let name):
                    return (weakObserver.value === observer as? NSObject) || name == aName
                case .observerWithObject(let weakObserver, _, let name, _):
                    return (weakObserver.value === observer as? NSObject) || name == aName
                case .observerWithBlock(let weakObserver, let name, _):
                    return (weakObserver.value === observer as? NSObject) || name == aName
                default:
                    return false
                }
            }
        }
    }

    /// We don't keep track of the actual objects, because removeObserver
    /// gets often called in dealloc, and we don't want to store an object about to be deallocated
    /// in an array.
    public var removeObserverInvocations = Invocations<Void>()
    public override func removeObserver(_ observer: any NSObjectProtocol) {
        if ignoreRemoveObserver == false {
            removeObserverInvocations.record(Void())
            observers.removeAll { item in
                switch item {
                case .observer(let weakObserver, _, _):
                    return weakObserver.value === observer as? NSObject
                case .observerWithObject(let weakObserver, _, _, _):
                    return weakObserver.value === observer as? NSObject
                case .observerWithBlock(let weakObserver, _, _):
                    return weakObserver.value === observer as? NSObject
                case .observerForKeyPath(let weakObserver, _, _, _):
                    return weakObserver.value === observer as? NSObject
                }
            }
        }
    }

    public var removeObserverWithNameAndObjectInvocations = Invocations<(name: NSNotification.Name, object: Any?)>()
    public override func removeObserver(
        _ observer: any NSObjectProtocol,
        name aName: NSNotification.Name,
        object anObject: Any?
    ) {
        if ignoreRemoveObserver == false {
            removeObserverWithNameAndObjectInvocations.record((aName, anObject))
            observers.removeAll { item in
                switch item {
                case .observer(let weakObserver, _, let name):
                    return (weakObserver.value === observer as? NSObject) || name == aName
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

    public var removeObserverForKeyPathInvocations = Invocations<String>()
    public override func removeObserver(_ observer: NSObject, forKeyPath keyPath: String) {
        if ignoreRemoveObserver == false {
            removeObserverForKeyPathInvocations.record(keyPath)
            observers.removeAll { item in
                switch item {
                case .observerForKeyPath(let weakObserver, let path, _, _):
                    return (weakObserver.value === observer) || path == keyPath
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

    public override func post(_ notification: Notification) {
        observers.forEach { observer in
            switch observer {
            case .observer(let weakObserver, let selector, let name):
                if name == notification.name {
                    _ = weakObserver.value?.perform(selector, with: notification)
                }
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
        addObserverInvocations.removeAll()
        addObserverWithObjectInvocations.removeAll()
        addObserverForKeyPathWithContextInvocations.removeAll()
        addObserverWithBlockInvocations.removeAll()
        removeObserverInvocations.removeAll()
        removeObserverWithNameInvocations.removeAll()
        removeObserverWithNameAndObjectInvocations.removeAll()
        removeObserverForKeyPathInvocations.removeAll()
        removeObserverForKeyPathWithContextInvocations.removeAll()
    }

    /// Helper method to get count of active observers
    public var observerCount: Int {
        return observers.count
    }
}
