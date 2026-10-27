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

typealias SentryHingeObserverHandler = (SentryHingeState) -> Void
typealias SentryHingeObserverToken = UUID

protocol SentryHingeObserving: AnyObject {
    /// The most recent hinge state, or nil before the first update and while nothing observes it.
    var currentState: SentryHingeState? { get }
    /// Adds a handler for hinge updates, which is called on the main thread. The first observer
    /// starts observing the hinge.
    func addObserver(_ handler: @escaping SentryHingeObserverHandler) -> SentryHingeObserverToken
    /// Removes the handler with the given token. Removing the last observer stops observing the hinge.
    func removeObserver(token: SentryHingeObserverToken)
}

/// Observes the hinge of foldable devices, such as iPhone Duo, through `UIHingeInteraction`, which
/// `SentryHingeInteractionShim` creates with or without the iOS 27.1 SDK.
///
/// A hinge interaction only receives updates while attached to a view hierarchy, so the observer
/// attaches one interaction to every window of the app and to every window that becomes key later.
final class SentryHingeObserver: NSObject, SentryHingeObserving {
    private struct State {
        var handlers: [SentryHingeObserverToken: SentryHingeObserverHandler] = [:]
        var currentState: SentryHingeState?
    }

    private let state = SentryMutex<State>(State())

    var currentState: SentryHingeState? {
        state.withLock { $0.currentState }
    }
    private let applicationProvider: () -> SentryApplication?
    private let notificationCenterWrapper: SentryNSNotificationCenterWrapper
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let interactionShim: SentryHingeInteractionShim

    /// The interactions attached to windows. Each interaction holds its window weakly as `view`,
    /// so interactions of deallocated windows are pruned on the next attach. UIKit owns both the
    /// windows and the interactions, so only `attach(to:)` and `detachFromAllWindows()` access this,
    /// and they only run on the main thread.
    private var interactions: [UIInteraction] = []

    init(
        applicationProvider: @escaping () -> SentryApplication?,
        notificationCenterWrapper: SentryNSNotificationCenterWrapper,
        dispatchQueueWrapper: SentryDispatchQueueWrapper,
        interactionShim: SentryHingeInteractionShim = SentryHingeInteractionShims.make()
    ) {
        self.applicationProvider = applicationProvider
        self.notificationCenterWrapper = notificationCenterWrapper
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.interactionShim = interactionShim
        super.init()
    }

    deinit {
        notificationCenterWrapper.removeObserver(self, name: nil, object: nil)
    }

    // MARK: - SentryHingeObserving

    func addObserver(_ handler: @escaping SentryHingeObserverHandler) -> SentryHingeObserverToken {
        let token = SentryHingeObserverToken()
        let isFirstObserver = state.withLock { state -> Bool in
            state.handlers[token] = handler
            return state.handlers.count == 1
        }
        if isFirstObserver {
            start()
        }
        return token
    }

    func removeObserver(token: SentryHingeObserverToken) {
        // Return the removed handler from `withLock`, so it is deallocated outside the critical
        // section. Its deinit chain could re-enter the lock and deadlock.
        let (_, wasLastObserver) = state.withLock { state -> (SentryHingeObserverHandler?, Bool) in
            guard let removed = state.handlers.removeValue(forKey: token) else {
                return (nil, false)
            }
            if state.handlers.isEmpty {
                state.currentState = nil
            }
            return (removed, state.handlers.isEmpty)
        }
        if wasLastObserver {
            stop()
        }
    }

    // MARK: - Lifecycle

    private func start() {
        guard interactionShim.isAvailable else {
            // Only unexpected on iOS 27.1 or later, so older runtimes don't warn on every launch.
            if #available(iOS 27.1, *) {
                SentrySDKLog.warning("UIHingeInteraction is not available. Won't observe hinge state changes.")
            } else {
                SentrySDKLog.debug("UIHingeInteraction requires iOS 27.1. Won't observe hinge state changes.")
            }
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

    private func stop() {
        guard interactionShim.isAvailable else {
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
        guard Thread.isMainThread else {
            SentrySDKLog.error("Hinge interactions can only be attached on the main thread.")
            return
        }
        let isRunning = state.withLock { !$0.handlers.isEmpty }
        interactions.removeAll { $0.view == nil }
        guard isRunning, !interactions.contains(where: { $0.view === window }) else {
            return
        }
        guard let interaction = interactionShim.makeInteraction(updateHandler: { [weak self] hingeState in
            self?.handleUpdate(hingeState)
        }) else {
            SentrySDKLog.warning("Could not create UIHingeInteraction. Won't observe hinge state changes.")
            return
        }
        window.addInteraction(interaction)
        interactions.append(interaction)
    }

    private func detachFromAllWindows() {
        guard Thread.isMainThread else {
            SentrySDKLog.error("Hinge interactions can only be detached on the main thread.")
            return
        }
        // A new observer can start observing again before this runs.
        guard state.withLock({ $0.handlers.isEmpty }) else {
            return
        }
        for interaction in interactions {
            interaction.view?.removeInteraction(interaction)
        }
        interactions.removeAll()
    }

    private func handleUpdate(_ hingeState: SentryHingeState?) {
        // A nil hinge means the interaction left a hierarchy that provides hinge updates, which
        // is not a state change of the device.
        guard let hingeState else {
            return
        }
        let handlers = state.withLock { state -> [SentryHingeObserverHandler] in
            guard !state.handlers.isEmpty else {
                return []
            }
            state.currentState = hingeState
            return Array(state.handlers.values)
        }
        for handler in handlers {
            handler(hingeState)
        }
    }
}

#endif // os(iOS) && !SENTRY_NO_UI_FRAMEWORK
