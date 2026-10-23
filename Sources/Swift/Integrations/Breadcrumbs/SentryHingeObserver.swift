internal import _SentryPrivate

#if os(iOS) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

/// The status of a device hinge. The raw values mirror `UIHingeStatus` from the iOS 27.1 SDK.
enum SentryHingeStatus: Int {
    case unknown = 0
    case closed = 1
    case partiallyOpen = 2
    case fullyOpen = 3

    /// The value written to breadcrumb data.
    var breadcrumbValue: String {
        switch self {
        case .unknown: return "unknown"
        case .closed: return "closed"
        case .partiallyOpen: return "partially_open"
        case .fullyOpen: return "fully_open"
        }
    }
}

/// A snapshot of a device hinge, as delivered by a `UIHingeInteraction` update.
struct SentryHingeState: Equatable {
    let status: SentryHingeStatus
    /// The hinge angle in radians, as reported by UIKit.
    let angle: Double
}

protocol SentryHingeObserving: AnyObject {
    /// Starts delivering hinge updates to `handler`. The handler is called on the main thread.
    func start(handler: @escaping (SentryHingeState) -> Void)
    func stop()
}

// `UIHingeInteraction` and `UIHinge` ship with the iOS 27.1 SDK. Xcode 27.0 and Xcode 27.1 both
// ship Swift 6.4, so `#if compiler(>=6.4)` cannot tell their SDKs apart. The SwiftUI module version
// can: the iOS 27.0 SDK ships SwiftUI 8.0.84 and the iOS 27.1 SDK ships SwiftUI 8.0.85, and the
// Mac Catalyst SDK of Xcode 27.1 still ships 8.0.84 together with the iOS 27.0 UIKit. SwiftUI is
// checked instead of UIKit because it is a pure Swift module, whose version is always readable,
// while the Clang module version of UIKit is not available in every build configuration. This gate
// is repeated in `SentryHingeObserverTests`, because Swift cannot define a compilation condition
// from source.
#if canImport(SwiftUI, _version: 8.0.85)

extension SentryHingeStatus {
    @available(iOS 27.1, *)
    init(_ status: UIHinge.Status) {
        switch status {
        case .unknown: self = .unknown
        case .closed: self = .closed
        case .partiallyOpen: self = .partiallyOpen
        case .fullyOpen: self = .fullyOpen
        @unknown default: self = .unknown
        }
    }
}

/// Observes the hinge of foldable devices, such as iPhone Duo, through `UIHingeInteraction`.
///
/// This implementation is only compiled with the iOS 27.1 SDK or later, so the feature is available
/// when building from source, such as with SwiftPM, with Xcode 27.1 or later. The prebuilt
/// XCFramework is compiled with an older Xcode and gets the no-op observer below instead.
///
/// A hinge interaction only receives updates while attached to a view hierarchy, so the observer
/// attaches one interaction to every window of the app and to every window that becomes key later.
final class SentryHingeObserver: NSObject, SentryHingeObserving {
    private struct State {
        var handler: ((SentryHingeState) -> Void)?
    }

    private let state = SentryMutex<State>(State())
    private let applicationProvider: () -> SentryApplication?
    private let notificationCenterWrapper: SentryNSNotificationCenterWrapper
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper

    /// Only accessed on the main thread, because UIKit owns both the windows and the interactions.
    /// The values are `UIHingeInteraction`, stored as `UIInteraction` because the property can't
    /// carry the iOS 27.1 availability of the concrete type.
    private let interactionsByWindow = NSMapTable<UIWindow, UIInteraction>.weakToStrongObjects()

    init(
        applicationProvider: @escaping () -> SentryApplication?,
        notificationCenterWrapper: SentryNSNotificationCenterWrapper,
        dispatchQueueWrapper: SentryDispatchQueueWrapper
    ) {
        self.applicationProvider = applicationProvider
        self.notificationCenterWrapper = notificationCenterWrapper
        self.dispatchQueueWrapper = dispatchQueueWrapper
        super.init()
    }

    deinit {
        notificationCenterWrapper.removeObserver(self, name: nil, object: nil)
    }

    /// Whether this build can observe the hinge, which requires the iOS 27.1 SDK at compile time
    /// and iOS 27.1 or later at runtime.
    static var isSupported: Bool {
        if #available(iOS 27.1, *) {
            return true
        }
        return false
    }

    // MARK: - SentryHingeObserving

    func start(handler: @escaping (SentryHingeState) -> Void) {
        guard Self.isSupported else {
            SentrySDKLog.debug("UIHingeInteraction requires iOS 27.1. Won't observe hinge state changes.")
            return
        }

        let wasRunning = state.withLock { state -> Bool in
            let wasRunning = state.handler != nil
            state.handler = handler
            return wasRunning
        }
        guard !wasRunning else {
            return
        }

        notificationCenterWrapper.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: UIWindow.didBecomeKeyNotification,
            object: nil
        )

        dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
            guard let self else { return }
            for window in self.applicationProvider()?.getWindows() ?? [] {
                self.attach(to: window)
            }
        }
    }

    func stop() {
        let wasRunning = state.withLock { state -> Bool in
            let wasRunning = state.handler != nil
            state.handler = nil
            return wasRunning
        }
        guard wasRunning else {
            return
        }

        notificationCenterWrapper.removeObserver(self, name: UIWindow.didBecomeKeyNotification, object: nil)

        dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
            self?.detachFromAllWindows()
        }
    }

    // MARK: - Window Tracking

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? UIWindow else {
            return
        }
        dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
            self?.attach(to: window)
        }
    }

    private func attach(to window: UIWindow) {
        guard #available(iOS 27.1, *) else {
            return
        }
        let isRunning = state.withLock { $0.handler != nil }
        guard isRunning, interactionsByWindow.object(forKey: window) == nil else {
            return
        }
        let interaction = UIHingeInteraction { [weak self] _, update in
            self?.handleUpdate(update)
        }
        window.addInteraction(interaction)
        interactionsByWindow.setObject(interaction, forKey: window)
    }

    private func detachFromAllWindows() {
        for case let window as UIWindow in interactionsByWindow.keyEnumerator() {
            if let interaction = interactionsByWindow.object(forKey: window) {
                window.removeInteraction(interaction)
            }
        }
        interactionsByWindow.removeAllObjects()
    }

    @available(iOS 27.1, *)
    private func handleUpdate(_ update: UIHingeInteraction.Update) {
        guard let handler = state.withLock({ $0.handler }) else {
            return
        }
        // A nil hinge means the interaction left a hierarchy that provides hinge updates, which
        // is not a state change of the device.
        guard let hinge = update.hinge else {
            return
        }
        handler(SentryHingeState(status: SentryHingeStatus(hinge.status), angle: hinge.angle))
    }
}

#else

/// The hinge observer for builds without the iOS 27.1 SDK, where `UIHingeInteraction` doesn't
/// exist. `start` is a no-op, so the hinge breadcrumbs are never added.
final class SentryHingeObserver: NSObject, SentryHingeObserving {
    /// Always false, because `UIHingeInteraction` is not available at compile time.
    static var isSupported: Bool { false }

    init(
        applicationProvider: @escaping () -> SentryApplication?,
        notificationCenterWrapper: SentryNSNotificationCenterWrapper,
        dispatchQueueWrapper: SentryDispatchQueueWrapper
    ) {
        super.init()
    }

    func start(handler: @escaping (SentryHingeState) -> Void) {
        SentrySDKLog.debug("Sentry was compiled without the iOS 27.1 SDK. Won't observe hinge state changes.")
    }

    func stop() {
        // Nothing was started.
    }
}

#endif // canImport(SwiftUI, _version: 8.0.85)

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
