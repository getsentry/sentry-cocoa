#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

import UIKit

/// Reports the UI updates UIKit produces.
///
/// - Warning: All members must be used on the main thread. The handler is always called on the main
/// thread.
protocol SentryUIUpdateObserving: AnyObject {
    /// When `true`, UIKit produces a UI update for every frame of the display, like a
    /// `CADisplayLink` does. When `false`, the handler is only called for UI updates that happen
    /// anyway, which keeps the app idle while nothing on screen changes.
    var requiresContinuousUpdates: Bool { get set }

    /// - Parameter handler: Called once per UI update with the duration of one frame of the display
    /// the update is for.
    func start(handler: @escaping (_ frameDuration: CFTimeInterval) -> Void)
    func stop()
}

// UIUpdateLink is unavailable on Mac Catalyst.
#if !targetEnvironment(macCatalyst)

/// Observes UI updates with one `UIUpdateLink` per connected window scene.
///
/// A `UIUpdateLink` can only be created from a window scene or a view. The SDK usually starts before
/// the app connects its first scene, so this finds the scenes through notifications and through the
/// scenes the application already has.
@available(iOS 18.0, tvOS 18.0, visionOS 2.0, *)
final class SentryUIUpdateLinkObserver: NSObject, SentryUIUpdateObserving {

    private let notificationCenter: SentryNSNotificationCenterWrapper
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let applicationProvider: () -> SentryApplication?

    private var handler: ((CFTimeInterval) -> Void)?
    private var links: [ObjectIdentifier: UIUpdateLink] = [:]
    private var previousModelTime: TimeInterval = -1

    var requiresContinuousUpdates: Bool = false {
        didSet {
            guard requiresContinuousUpdates != oldValue else { return }
            for link in links.values {
                link.requiresContinuousUpdates = requiresContinuousUpdates
            }
        }
    }

    init(
        notificationCenter: SentryNSNotificationCenterWrapper,
        dispatchQueueWrapper: SentryDispatchQueueWrapper,
        applicationProvider: @escaping () -> SentryApplication?
    ) {
        self.notificationCenter = notificationCenter
        self.dispatchQueueWrapper = dispatchQueueWrapper
        self.applicationProvider = applicationProvider
        super.init()
    }

    deinit {
        removeNotificationObservers()

        // UIUpdateLink is bound to the main thread, but this can be deallocated on any thread.
        let links = Array(self.links.values)
        guard !links.isEmpty else { return }
        dispatchQueueWrapper.dispatchAsyncOnMainQueueIfNotMainThread {
            for link in links {
                link.isEnabled = false
            }
        }
    }

    func start(handler: @escaping (_ frameDuration: CFTimeInterval) -> Void) {
        guard self.handler == nil else { return }
        self.handler = handler

        notificationCenter.addObserver(self, selector: #selector(sceneWillConnect(_:)), name: UIScene.willConnectNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(sceneDidDisconnect(_:)), name: UIScene.didDisconnectNotification, object: nil)
        // Covers window scenes that connected without this observing it, for example when the
        // application object isn't available.
        notificationCenter.addObserver(self, selector: #selector(windowDidBecomeVisible(_:)), name: UIWindow.didBecomeVisibleNotification, object: nil)

        for scene in applicationProvider()?.connectedScenes ?? [] {
            attach(to: scene)
        }
    }

    func stop() {
        guard handler != nil else { return }
        handler = nil

        removeNotificationObservers()

        for link in links.values {
            link.isEnabled = false
        }
        links.removeAll()
        previousModelTime = -1
    }

    private func removeNotificationObservers() {
        notificationCenter.removeObserver(self, name: UIScene.willConnectNotification, object: nil)
        notificationCenter.removeObserver(self, name: UIScene.didDisconnectNotification, object: nil)
        notificationCenter.removeObserver(self, name: UIWindow.didBecomeVisibleNotification, object: nil)
    }

    @objc
    private func sceneWillConnect(_ notification: Notification) {
        guard let scene = notification.object as? UIScene else { return }
        attach(to: scene)
    }

    @objc
    private func sceneDidDisconnect(_ notification: Notification) {
        guard let scene = notification.object as? UIScene else { return }
        links.removeValue(forKey: ObjectIdentifier(scene))?.isEnabled = false
    }

    @objc
    private func windowDidBecomeVisible(_ notification: Notification) {
        guard let scene = (notification.object as? UIWindow)?.windowScene else { return }
        attach(to: scene)
    }

    private func attach(to scene: UIScene) {
        guard handler != nil, let windowScene = scene as? UIWindowScene else { return }

        let key = ObjectIdentifier(windowScene)
        guard links[key] == nil else { return }

        let link = UIUpdateLink(windowScene: windowScene)
        // After the commit, the update's changes are on their way to the render server, which is the
        // closest UIKit gets to telling that a frame was drawn.
        link.addAction(to: .afterCATransactionCommit) { [weak self] _, info in
            self?.updateCommitted(info)
        }
        link.requiresContinuousUpdates = requiresContinuousUpdates
        link.isEnabled = true
        links[key] = link

        SentrySDKLog.debug("Observing UI updates of window scene \(windowScene.session.persistentIdentifier).")
    }

    private func updateCommitted(_ info: UIUpdateInfo) {
        // Window scenes on the same display share their UI updates, so every link reports the same
        // update.
        guard info.modelTime != previousModelTime else { return }
        previousModelTime = info.modelTime

        handler?(info.completionDeadlineTime - info.modelTime)
    }
}

#endif // !targetEnvironment(macCatalyst)

#endif
