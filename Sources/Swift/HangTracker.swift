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

/// A class to observe when the main runloop is blocked.
///
/// > Warning: All public APIs must be called on the main queue. This includes init and deinit.
// A "healthy" runloop spends most of its
// time waiting for events, but a hanging runloop is spending a lot of time handling events.
// A hang can only be detected on a background queue, because the main queue is blocked by the hang.
// So the tracker runs a background queue that attempts to trigger a callback when the time between "afterWaiting"
// and "beforeWaiting" has exceeded the expected frame rate. We say "attempts" because it's always possible
// that the background queue does not get scheduled during the hang and the hang starts and finishes
// before we are able to detect that it is in progress.
//
// The general approach is to create a semaphore when the runloop leaves the waiting state "afterWaiting"
// and asynchronously start a background queue that waits on that semaphore. When the runloop enters waiting
// "beforeWaiting" we signal the semaphore. This way, if the background queue waiting times out, we know
// it took too long for the runloop to go back to waiting and a hang has occurred.
//
// Design requirements:
// 1: We don't want the hang tracker to cause any thing more than a constant number of extra runloop iterations.
// A fixed number of extra runloops per hang is acceptable, for example if it needed to run a dispatch_async
// on the main queue, but spinning the runloop indefinitely is not acceptable.
// 2: We don't want to acquire any locks every iteration of the runloop. It's ok to acquire locks in general
// (the code does not need to be async signal safe) but it's not ok to aquire them on every runloop iteration.
// 3: As simple as possible, using limited lines of code.
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
    
    // Must be called on main queue
    // The handler is always called on the same background queue. This guarantees
    // sequentially ordering of the callback. If it's called at least once with ongoing = True
    // it will eventually be called with ongoing = False, or the app will exit
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
    
    // These are injected dependencies that provide testability
    private let dateProvider: SentryCurrentDateProvider
    private let createObserver: CreateObserverFunc<T>
    private let addObserver: AddObserverFunc<T>
    private let removeObserver: RemoveObserverFunc<T>
    
    // Observers is the only state that uses a lock. It should only be modified
    // on the main queue, while the lock is held. Reading it on the main queue
    // does not require a lock. Reading it on a background queue does require the lock.
    private let observersLock = NSRecursiveLock()
    private var observers = [UUID: (TimeInterval, Bool) -> Void]()
    
    // MARK: Main queue

    // For the readers convenience, this encapsulates all the mutable state that can
    // only be used from the main queue.
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
                // In the future we may have use cases for reporting any hang, even if we weren't able to observe it while it
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
