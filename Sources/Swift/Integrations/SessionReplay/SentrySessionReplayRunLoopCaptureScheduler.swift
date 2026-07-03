// swiftlint:disable missing_docs
import Foundation

#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UI_FRAMEWORK

@_spi(Private) public protocol SentrySessionReplayRunLoopCaptureScheduler: AnyObject {
    // The token owns the installed observer so stale stops from an old replay cannot remove a newer replay's observer.
    func start(token: AnyObject, capture: @escaping (_ isInteractiveRunLoopMode: Bool) -> Void)
    func stop(token: AnyObject)
}

final class DefaultSentrySessionReplayRunLoopCaptureScheduler<T: SentryRunLoopObserver>: SentrySessionReplayRunLoopCaptureScheduler {
    private var observer: T?
    private var token: AnyObject?
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

    func start(token: AnyObject, capture: @escaping (Bool) -> Void) {
        runOnMainThreadSync { [weak self] in
            self?.startOnMainThread(token: token, capture: capture)
        }
    }

    func stop(token: AnyObject) {
        runOnMainThreadSync { [weak self] in
            self?.stopOnMainThread(token: token)
        }
    }

    private func startOnMainThread(token: AnyObject, capture: @escaping (Bool) -> Void) {
        if let currentToken = self.token {
            guard currentToken !== token else { return }
            removeCurrentObserver()
        }

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
        self.token = token
        addObserver(CFRunLoopGetMain(), observer, .commonModes)
    }

    private func stopOnMainThread(token: AnyObject) {
        guard self.token === token else { return }
        removeCurrentObserver()
    }

    private func removeCurrentObserver() {
        didProcessRunLoopWork = false
        self.token = nil
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

    private func runOnMainThreadSync(_ block: () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync(execute: block)
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
