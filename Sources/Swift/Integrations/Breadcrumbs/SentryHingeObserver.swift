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
    /// The most recent hinge state, or nil before the first update and after `stop`.
    var currentState: SentryHingeState? { get }
    /// Starts delivering hinge updates to `handler`. The handler is called on the main thread.
    func start(handler: @escaping (SentryHingeState) -> Void)
    func stop()
}

/// Observes the hinge of foldable devices, such as iPhone Duo, through `UIHingeInteraction`.
///
/// `UIHingeInteraction` and `UIHinge` only exist in the iOS 27.1 SDK, which is newer than the oldest
/// Xcode this SDK supports, so the interaction is created through the Objective-C runtime instead of
/// referencing the symbols directly. On a runtime without the class, `start` is a no-op.
///
/// Referencing the symbols behind a `#if compiler(>=6.4)` gate with `#available(iOS 27.1, *)` would
/// work when building from source with Xcode 27.1 or later, such as with SwiftPM. It would silently
/// drop this feature from the prebuilt XCFramework, because that is compiled with an older Xcode
/// whose SDK lacks the symbols. The runtime lookup keeps the feature in every distribution.
///
/// A hinge interaction only receives updates while attached to a view hierarchy, so the observer
/// attaches one interaction to every window of the app and to every window that becomes key later.
final class SentryHingeObserver: NSObject, SentryHingeObserving {
    private static let interactionClassName = "UIHingeInteraction"
    private static let initSelector = NSSelectorFromString("initWithUpdateHandler:")
    private static let hingeSelector = NSSelectorFromString("hinge")
    private static let statusSelector = NSSelectorFromString("status")
    private static let angleSelector = NSSelectorFromString("angle")

    private struct State {
        var handler: ((SentryHingeState) -> Void)?
        var currentState: SentryHingeState?
    }

    private let state = SentryMutex<State>(State())

    var currentState: SentryHingeState? {
        state.withLock { $0.currentState }
    }
    private let applicationProvider: () -> SentryApplication?
    private let notificationCenterWrapper: SentryNSNotificationCenterWrapper
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper

    /// Only accessed on the main thread, because UIKit owns both the windows and the interactions.
    private let interactionsByWindow = NSMapTable<UIWindow, AnyObject>.weakToStrongObjects()

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

    /// Whether the current runtime provides `UIHingeInteraction`, which requires iOS 27.1 or later.
    static var isHingeInteractionAvailable: Bool {
        NSClassFromString(interactionClassName) != nil
    }

    // MARK: - SentryHingeObserving

    func start(handler: @escaping (SentryHingeState) -> Void) {
        guard Self.isHingeInteractionAvailable else {
            SentrySDKLog.debug("\(Self.interactionClassName) is not available. Won't observe hinge state changes.")
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
            state.currentState = nil
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
        let isRunning = state.withLock { $0.handler != nil }
        guard isRunning, interactionsByWindow.object(forKey: window) == nil else {
            return
        }
        guard let interaction = makeInteraction() else {
            SentrySDKLog.warning("Could not create \(Self.interactionClassName). Won't observe hinge state changes.")
            return
        }
        window.addInteraction(interaction)
        interactionsByWindow.setObject(interaction, forKey: window)
    }

    private func detachFromAllWindows() {
        for case let window as UIWindow in interactionsByWindow.keyEnumerator() {
            if let interaction = interactionsByWindow.object(forKey: window) as? UIInteraction {
                window.removeInteraction(interaction)
            }
        }
        interactionsByWindow.removeAllObjects()
    }

    // MARK: - Dynamic UIHingeInteraction

    private func makeInteraction() -> UIInteraction? {
        guard let interactionClass = NSClassFromString(Self.interactionClassName) as? NSObject.Type,
              interactionClass.instancesRespond(to: Self.initSelector) else {
            return nil
        }

        // The handler signature is (UIHingeInteraction *, UIHingeInteractionUpdate *).
        let handler: @convention(block) (AnyObject, AnyObject) -> Void = { [weak self] _, update in
            self?.handleUpdate(update)
        }
        let handlerBlock = unsafeBitCast(handler, to: AnyObject.self)

        // `alloc` returns a +1 reference that `initWithUpdateHandler:` consumes, and init returns a
        // +1 reference that we take ownership of. Taking the alloc result unretained keeps the
        // retain counts balanced even if init returns a different object.
        guard let allocated = (interactionClass as AnyObject).perform(NSSelectorFromString("alloc"))?.takeUnretainedValue(),
              let interaction = allocated.perform(Self.initSelector, with: handlerBlock)?.takeRetainedValue() else {
            return nil
        }
        return interaction as? UIInteraction
    }

    private func handleUpdate(_ update: AnyObject) {
        guard let handler = state.withLock({ $0.handler }) else {
            return
        }
        // A nil hinge means the interaction left a hierarchy that provides hinge updates, which
        // is not a state change of the device.
        guard let hingeState = Self.hingeState(from: update) else {
            return
        }
        state.withLock { $0.currentState = hingeState }
        handler(hingeState)
    }

    /// Reads the `hinge` of a `UIHingeInteractionUpdate` through key-value coding.
    ///
    /// Every key is guarded with `responds(to:)` first, because an undefined key raises an
    /// Objective-C exception that Swift cannot catch.
    static func hingeState(from update: AnyObject) -> SentryHingeState? {
        guard let update = update as? NSObject,
              update.responds(to: hingeSelector),
              let hinge = update.value(forKey: "hinge") as? NSObject,
              hinge.responds(to: statusSelector),
              hinge.responds(to: angleSelector),
              let rawStatus = hinge.value(forKey: "status") as? Int,
              let angle = hinge.value(forKey: "angle") as? Double else {
            return nil
        }
        let status = SentryHingeStatus(rawValue: rawStatus) ?? .unknown
        return SentryHingeState(status: status, angle: angle)
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
