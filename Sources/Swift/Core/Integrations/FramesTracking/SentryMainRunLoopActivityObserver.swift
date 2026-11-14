#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK

import Foundation

/// Reports the activities of the main run loop that delimit work on the main thread.
///
/// - Warning: `start` and `stop` must be called on the main thread. The handler is always called on
/// the main thread.
protocol SentryMainRunLoopActivityObserving: AnyObject {
    func start(handler: @escaping (CFRunLoopActivity) -> Void)
    func stop()
}

/// Observes the main run loop without waking it up, so observing costs nothing while the app is idle.
///
/// The time between two consecutive activities is time the main thread spent working, except for the
/// time between `beforeWaiting` and `afterWaiting`, which is time it spent waiting for work.
final class SentryMainRunLoopActivityObserver: SentryMainRunLoopActivityObserving {

    private var observers: [CFRunLoopObserver] = []

    deinit {
        // CFRunLoopRemoveObserver is thread-safe, and this is the only reference to self.
        removeObservers()
    }

    func start(handler: @escaping (CFRunLoopActivity) -> Void) {
        guard observers.isEmpty else { return }

        // An observer has only one order, but the time the main thread waits must be delimited as
        // tightly as possible. Other observers, such as the Core Animation transaction commit, do
        // their work in `beforeWaiting` and `afterWaiting`. To count that work as work, one observer
        // has to run after all others before the run loop waits, and another one before all others
        // after it wakes up.
        let beforeOthers: CFRunLoopActivity = [.entry, .beforeTimers, .afterWaiting]
        let afterOthers: CFRunLoopActivity = [.beforeWaiting, .exit]

        let created = [
            CFRunLoopObserverCreateWithHandler(nil, beforeOthers.rawValue, true, CFIndex.min) { _, activity in
                handler(activity)
            },
            CFRunLoopObserverCreateWithHandler(nil, afterOthers.rawValue, true, CFIndex.max) { _, activity in
                handler(activity)
            }
        ]

        for observer in created {
            guard let observer else { continue }
            CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
            observers.append(observer)
        }
    }

    func stop() {
        removeObservers()
    }

    private func removeObservers() {
        for observer in observers {
            CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
        }
        observers.removeAll()
    }
}

#endif
