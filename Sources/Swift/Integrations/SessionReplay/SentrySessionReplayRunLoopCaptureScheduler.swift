// swiftlint:disable missing_docs
import Foundation

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

protocol SentrySessionReplayRunLoopCaptureScheduler: AnyObject {
    func start(capture: @escaping (_ isInteractiveRunLoopMode: Bool) -> Void)
    func stop()
}

final class DefaultSentrySessionReplayRunLoopCaptureScheduler<T: RunLoopObserver>: SentrySessionReplayRunLoopCaptureScheduler {
    private var observer: T?
    private var didProcessRunLoopWork = false
    private let createObserver: CreateObserverFunc<T>
    private let addObserver: AddObserverFunc<T>
    private let removeObserver: RemoveObserverFunc<T>
    private let currentRunLoopMode: () -> RunLoop.Mode?
    private let isValidObserver: (T) -> Bool

    init(
        createObserver: @escaping CreateObserverFunc<T>,
        addObserver: @escaping AddObserverFunc<T>,
        removeObserver: @escaping RemoveObserverFunc<T>,
        currentRunLoopMode: @escaping () -> RunLoop.Mode? = { RunLoop.current.currentMode },
        isValidObserver: @escaping (T) -> Bool = { _ in true }
    ) {
        self.createObserver = createObserver
        self.addObserver = addObserver
        self.removeObserver = removeObserver
        self.currentRunLoopMode = currentRunLoopMode
        self.isValidObserver = isValidObserver
    }

    func start(capture: @escaping (Bool) -> Void) {
        runOnMainThread { [weak self] in
            self?.startOnMainThread(capture: capture)
        }
    }

    func stop() {
        runOnMainThread { [weak self] in
            self?.stopOnMainThread()
        }
    }

    private func startOnMainThread(capture: @escaping (Bool) -> Void) {
        guard observer == nil else { return }

        let activities = CFRunLoopActivity.afterWaiting.rawValue
            | CFRunLoopActivity.beforeTimers.rawValue
            | CFRunLoopActivity.beforeSources.rawValue
            | CFRunLoopActivity.beforeWaiting.rawValue
            | CFRunLoopActivity.exit.rawValue

        let observer = createObserver(
            kCFAllocatorDefault,
            activities,
            true,
            CFIndex.max
        ) { [weak self] observer, activity in
            guard let observer = observer,
                let self = self,
                self.isValidObserver(observer),
                self.shouldCapture(activity: activity)
            else { return }

            capture(self.currentRunLoopMode() == .tracking)
        }
        guard let observer = observer else { return }

        self.observer = observer
        addObserver(CFRunLoopGetMain(), observer, .commonModes)
    }

    private func stopOnMainThread() {
        didProcessRunLoopWork = false
        guard let observer = observer else { return }

        self.observer = nil
        removeObserver(CFRunLoopGetMain(), observer, .commonModes)
    }

    private func shouldCapture(activity: CFRunLoopActivity) -> Bool {
        if activity.contains(.afterWaiting)
            || activity.contains(.beforeTimers)
            || activity.contains(.beforeSources) {
            didProcessRunLoopWork = true
            return false
        }

        guard activity.contains(.beforeWaiting) || activity.contains(.exit) else { return false }
        guard didProcessRunLoopWork else { return false }

        didProcessRunLoopWork = false
        return true
    }

    private func runOnMainThread(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}

extension DefaultSentrySessionReplayRunLoopCaptureScheduler where T == CFRunLoopObserver {
    convenience init() {
        self.init(
            createObserver: CFRunLoopObserverCreateWithHandler,
            addObserver: CFRunLoopAddObserver,
            removeObserver: CFRunLoopRemoveObserver,
            isValidObserver: CFRunLoopObserverIsValid
        )
    }
}

#endif
// swiftlint:enable missing_docs
