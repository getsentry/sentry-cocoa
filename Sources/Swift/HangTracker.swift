@_implementationOnly import _SentryPrivate
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

protocol HangTrackerProvider {
    var hangTracker: HangTracker { get }
}
extension SentryDependencyContainer: HangTrackerProvider { }

#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol HangTracker {
    func addOngoingHangObserver(handler: @escaping (_ duration: TimeInterval, _ ongoing: Bool) -> Void) -> UUID
    
    func removeObserver(id: UUID)
}
protocol RunLoopObserver { }

extension DefaultHangTracker: HangTracker { }
extension CFRunLoopObserver: RunLoopObserver { }
#else
typealias HangTracker = DefaultHangTracker<CFRunLoopObserver>
typealias RunLoopObserver = CFRunLoopObserver
#endif

typealias CreateObserverFunc<T> = (_ allocator: CFAllocator?, _ activities: CFOptionFlags, _ repeats: Bool, _ order: CFIndex, _ block: ((T?, CFRunLoopActivity) -> Void)?) -> T?
typealias AddObserverFunc<T> = (_ rl: CFRunLoop?, _ observer: T?, _ mode: CFRunLoopMode?) -> Void
typealias RemoveObserverFunc<T> = (_ rl: CFRunLoop?, _ observer: T?, _ mode: CFRunLoopMode?) -> Void

final class DefaultHangTracker<T: RunLoopObserver> {

    // Must be initialized on the main queue
    init(
        dateProvider: SentryCurrentDateProvider,
        createObserver: @escaping CreateObserverFunc<T>,
        addObserver: @escaping AddObserverFunc<T>,
        removeObserver: @escaping RemoveObserverFunc<T>,
        queue: DispatchQueue = DispatchQueue(label: "io.sentry.runloop-observer-checker")
    ) {
        self.dateProvider = dateProvider
        self.createObserver = createObserver
        self.addObserver = addObserver
        self.removeObserver = removeObserver
        self.queue = queue
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && !os(visionOS) && !os(watchOS)
        let window = UIApplication.shared.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] }.first { $0.isKeyWindow }
        let maxFPS = Double(window?.screen.maximumFramesPerSecond ?? 60)
#else
        let maxFPS: Double = 60.0
        #endif
        let expectedFrameDuration = 1.0 / maxFPS
        hangNotifyThreshold = expectedFrameDuration * 1.5
        mainQueueState = .init()
    }
    
    deinit {
        guard let observer = mainQueueState.observer else {
            return
        }
        removeObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
    
    // Must be calleld on main queue
    // The handler is always called on a background queue. If it's called at least once with ongoing = True
    // it will eventaully be called with ongoing = False, or the app will exit
    func addOngoingHangObserver(handler: @escaping (_ duration: TimeInterval, _ ongoing: Bool) -> Void) -> UUID {
        let id = UUID()
        // Modifying observers requires holding the lock
        observersLock.synchronized {
            observers[id] = handler
        }
        startIfNecessary()
        return id
    }
    
    // Must be called on main queue
    func removeObserver(id: UUID) {
        // Modifying observers requires holding the lock
        observersLock.synchronized {
            _ = observers.removeValue(forKey: id)
        }
        if observers.isEmpty {
            stop()
        }
    }
    
    // This queue is used to detect main thread hangs, they need to be detected on a background thread
    // since the main thread is hanging.
    private let queue: DispatchQueue
    private let hangNotifyThreshold: TimeInterval
    private let dateProvider: SentryCurrentDateProvider
    private let createObserver: CreateObserverFunc<T>
    private let addObserver: AddObserverFunc<T>
    private let removeObserver: RemoveObserverFunc<T>
    private let observersLock = NSRecursiveLock()
    private var observers = [UUID: (TimeInterval, Bool) -> Void]()
    
    // MARK: Main queue

    struct MainQueueState {
        fileprivate var observer: T?
        fileprivate var semaphore: DispatchSemaphore?
        fileprivate var loopStartTime: TimeInterval?
    }
    private var mainQueueState: MainQueueState
    
    // Must be called on main queue
    private func startIfNecessary() {
        guard mainQueueState.observer == nil else {
            // Already running
            return
        }

        let observer = createObserver(nil, CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.afterWaiting.rawValue, true, CFIndex(INT_MAX)) { [weak self] _, activity in
            guard let self else { return }

            let currentTime = dateProvider.systemUptime()
            switch activity {
            case .beforeWaiting:
                mainQueueState.semaphore?.signal()
                // In the future we may have use cases for reporting any hang, even if we weren't able to observer it while it
                // was ongoing. To do that we could add another observer type, and call it here with `currentTime - mainQueueState.loopStartTime`
            case .afterWaiting:
                let started = currentTime
                mainQueueState.loopStartTime = currentTime
                let localSemaphore = DispatchSemaphore(value: 0)
                mainQueueState.semaphore = localSemaphore
                queue.async { [weak self] in
                    self?.waitForHang(semaphore: localSemaphore, started: started)
                }
            default:
                // We want this to crash in debug to quickly catch issues but never in production
                assertionFailure("Unexpected run loop activity \(activity)")
            }
        }
        mainQueueState.observer = observer
        addObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
    
    // Must be called on main queue
    private func stop() {
        guard let observer = mainQueueState.observer else {
            return
        }
        removeObserver(CFRunLoopGetMain(), observer, .commonModes)
        mainQueueState.observer = nil
        mainQueueState.loopStartTime = nil
        // If we are between beforeWaiting and afterWaiting the background queue is waiting for a signal, so let it proceed.
        mainQueueState.semaphore?.signal()
        mainQueueState.semaphore = nil
    }
    
    // MARK: Background queue
    
    // Must be called on background queue
    private func waitForHang(semaphore: DispatchSemaphore, started: TimeInterval) {
        var hasTimedOut = false
        var semaphoreSuccess = false
        while !semaphoreSuccess {
            let timeout = DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(hangNotifyThreshold * 1_000))
            let result = semaphore.wait(timeout: timeout)
            let duration = dateProvider.systemUptime() - started
            switch result {
            case .timedOut:
                // Accessing observers off the main queue requires holding the lock
                // because the main queue could be modifying it
                observersLock.synchronized {
                    observers.values.forEach {
                        $0(duration, true)
                    }
                }
                hasTimedOut = true
            case .success:
                semaphoreSuccess = true
                if hasTimedOut {
                    // A hang had occured, but now is over
                    // Accessing observers off the main queue requires holding the lock
                    // because the main queue could be modifying it
                    observersLock.synchronized {
                        observers.values.forEach {
                            $0(duration, false)
                        }
                    }
                }
            }
        }
    }
}

extension DefaultHangTracker where T == CFRunLoopObserver {
    convenience init(dateProvider: SentryCurrentDateProvider) {
        self.init(
            dateProvider: dateProvider,
            createObserver: CFRunLoopObserverCreateWithHandler,
            addObserver: CFRunLoopAddObserver,
            removeObserver: CFRunLoopRemoveObserver)
    }
}
