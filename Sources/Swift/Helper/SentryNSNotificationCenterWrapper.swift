// swiftlint:disable missing_docs
import Foundation

// This is needed because a file that only contains an @objc extension will get automatically stripped out
// in static builds. We need to either use the -all_load linker flag (which has downsides of app size increases)
// or make sure that every file containing objc categories/extensions also have a concrete type that
// is referenced. Once `SentryNSNotificationCenterWrapper` is not using `@objc` this can be removed.
@_spi(Private) @objc public final class PlaceholderNotificationCenterClass: NSObject { }

@objc @_spi(Private) public protocol SentryNSNotificationCenterWrapper {
    func addObserver(_ observer: Any, selector aSelector: Selector, name aName: NSNotification.Name?, object anObject: Any?)
    @objc(addObserverForName:object:queue:usingBlock:)
    func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @Sendable @escaping (Notification) -> Void) -> NSObjectProtocol
    func removeObserver(_ observer: Any, name aName: NSNotification.Name?, object anObject: Any?)
    @objc(postNotification:)
    func post(_ notification: Notification)
}

@objc @_spi(Private) extension NotificationCenter: SentryNSNotificationCenterWrapper { }
// swiftlint:enable missing_docs
