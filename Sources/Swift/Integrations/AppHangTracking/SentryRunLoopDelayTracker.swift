@_implementationOnly import _SentryPrivate
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

typealias SentryRunLoopDelayTrackerHandler = (_ delay: SentryRunLoopDelay) -> Void
typealias SentryRunLoopDelayTrackerObserverToken = UUID

// In test/debug builds we use a protocol so that the tracker can be replaced with a mock.
// In release builds the protocol indirection is eliminated via typealiases.
#if SENTRY_TEST || SENTRY_TEST_CI || DEBUG
protocol SentryRunLoopDelayTracker {
    func addObserver(handler: @escaping SentryRunLoopDelayTrackerHandler) -> SentryRunLoopDelayTrackerObserverToken
    func removeObserver(token: SentryRunLoopDelayTrackerObserverToken)
}
extension SentryDefaultRunLoopDelayTracker: SentryRunLoopDelayTracker { }

protocol SentryRunLoopObserver { }
extension CFRunLoopObserver: SentryRunLoopObserver { }

typealias SentryRunLoopDelayTrackerDependencies = DateProviderProvider & ApplicationProvider
#else
typealias SentryRunLoopDelayTracker = SentryDefaultRunLoopDelayTracker<CFRunLoopObserver, SentryDependencyContainer>
typealias SentryRunLoopObserver = CFRunLoopObserver
typealias SentryRunLoopDelayTrackerDependencies = SentryDependencyContainer
#endif

// Mirrors CFRunLoopObserver{CreateWithHandler,Add,Remove} signatures so tests can inject fakes.
typealias CreateObserverFunc<T> = (_ allocator: CFAllocator?, _ activities: CFOptionFlags, _ repeats: Bool, _ order: CFIndex, _ block: ((T?, CFRunLoopActivity) -> Void)?) -> T?
typealias AddObserverFunc<T> = (_ rl: CFRunLoop?, _ observer: T?, _ mode: CFRunLoopMode?) -> Void
typealias RemoveObserverFunc<T> = (_ rl: CFRunLoop?, _ observer: T?, _ mode: CFRunLoopMode?) -> Void

/// Observes when the main runloop is blocked, polling at ~25ms intervals (~1.5x the expected frame duration).
///
/// A "healthy" runloop spends most of its time waiting for events, but a hanging runloop is spending a lot of time handling events.
/// A hang can only be detected on a background queue, because the main queue is blocked by the hang.
/// So the tracker runs a background queue that attempts to trigger a callback when the time between "afterWaiting"
/// and "beforeWaiting" has exceeded the expected frame rate. We say "attempts" because it's always possible
/// that the background queue does not get scheduled during the hang and the hang starts and finishes
/// before we are able to detect that it is in progress.
///
/// The general approach is to create a semaphore when the runloop leaves the waiting state `afterWaiting`
/// and asynchronously start a background queue that waits on that semaphore. When the runloop enters waiting
/// `beforeWaiting` we signal the semaphore. This way, if the background queue waiting times out, we know
/// it took too long for the runloop to go back to waiting and a hang has occurred.
///
/// ## Design requirements:
///
/// 1. We don't want the hang tracker to cause anything more than a constant number of extra runloop iterations.
///   A fixed number of extra runloops per hang is acceptable, for example if it needed to run a ``dispatch_async``
///   on the main queue, but spinning the runloop indefinitely is not acceptable.
/// 2. We don't want to acquire any locks every iteration of the runloop. It's ok to acquire locks in general
///   (the code does not need to be async signal safe) but it's not ok to acquire them on every runloop iteration.
/// 3. As simple as possible, using limited lines of code.
///
/// - Warning: All public APIs must be called on the main queue. This includes init and deinit.
final class SentryDefaultRunLoopDelayTracker<T: SentryRunLoopObserver, Dependencies: SentryRunLoopDelayTrackerDependencies> {
    // MARK: - Types

    /// Data structure encapsulating all mutable state that **must** only be used from the main queue.
    struct MainQueueState {
        fileprivate var observer: T?
        fileprivate var semaphore: DispatchSemaphore?
        fileprivate var loopStartTime: TimeInterval?
    }

    // MARK: - State

    private let queue: DispatchQueue
    private let pollingInterval: TimeInterval

    private let dateProvider: SentryCurrentDateProvider
    private let createObserver: CreateObserverFunc<T>
    private let addObserver: AddObserverFunc<T>
    private let removeObserver: RemoveObserverFunc<T>

    private let observers = SentryMutex<[SentryRunLoopDelayTrackerObserverToken: SentryRunLoopDelayTrackerHandler]>([:])
    private var mainQueueState: MainQueueState

    // MARK: - Implementation

    /// Creates a new RunLoop delay tracker using the given observer functions
    ///
    /// - Precondition: Must be initialized on the main queue
    init(
        dependencies: Dependencies,
        createObserver: @escaping CreateObserverFunc<T>,
        addObserver: @escaping AddObserverFunc<T>,
        removeObserver: @escaping RemoveObserverFunc<T>,
        queue: DispatchQueue = DispatchQueue(label: "io.sentry.runloop-observer-checker")
    ) {
        self.dateProvider = dependencies.dateProvider
        self.createObserver = createObserver
        self.addObserver = addObserver
        self.removeObserver = removeObserver
        self.queue = queue
#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && !os(visionOS) && !os(watchOS)
        let window = dependencies.application()?.getKeyWindow()
        let maxFPS = Double(window?.screen.maximumFramesPerSecond ?? 60)
#else
        let maxFPS: Double = 60.0
#endif
        let expectedFrameDuration = 1.0 / maxFPS
        pollingInterval = expectedFrameDuration * 1.5
        mainQueueState = .init()
    }

    deinit {
        // It's safe to access mainQueueState here regardless of the thread
        // because this is the only reference to `self` while it is being deallocated.
        guard let observer = mainQueueState.observer else {
            return
        }
        removeObserver(CFRunLoopGetMain(), observer, .commonModes)
    }

    /// Adds an observer to the tracker
    ///
    /// The observer/handler is always called on the same background queue. This guarantees
    /// sequential ordering of the callbacks. If it's called at least once with `isOngoing` set to `true`
    /// it will eventually be called with `isOngoing` set to `false`, or the app will exit.
    ///
    /// - Precondition: Must be called on main queue
    func addObserver(handler: @escaping SentryRunLoopDelayTrackerHandler) -> SentryRunLoopDelayTrackerObserverToken {
        let token = SentryRunLoopDelayTrackerObserverToken()
        observers.withLock {
            $0[token] = handler
        }
        startIfNecessary()
        return token
    }

    /// Removes the observer with the given token
    ///
    /// - Precondition: Must be called on main queue
    func removeObserver(token: SentryRunLoopDelayTrackerObserverToken) {
        // Prevent the removed handler from being deallocated inside `withLock`; its deinit chain could
        // re-enter the lock and deadlock.
        let (_, isEmpty) = observers.withLock {
            ($0.removeValue(forKey: token), $0.isEmpty)
        }

        if isEmpty {
            stop()
        }
    }

    /// - Precondition: Must be called on main queue
    private func startIfNecessary() {
        guard mainQueueState.observer == nil else {
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
                    self?.waitForDelay(semaphore: localSemaphore, started: started)
                }
            default:
                assertionFailure("Unexpected run loop activity \(activity)")
            }
        }
        mainQueueState.observer = observer
        addObserver(CFRunLoopGetMain(), observer, .commonModes)
    }

    /// - Precondition: Must be called on main queue
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

    /// - Precondition: Must be called on background queue
    private func waitForDelay(semaphore: DispatchSemaphore, started: TimeInterval) {
        var hasTimedOut = false
        var semaphoreSuccess = false
        while !semaphoreSuccess {
            let timeout = DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(pollingInterval * 1_000))
            let result = semaphore.wait(timeout: timeout)
            let duration = dateProvider.systemUptime() - started
            switch result {
            case .timedOut:
                // Snapshot handlers outside the critical section to avoid deadlocks if a handler calls addObserver/removeObserver.
                 let handlers = observers.withLock { Array($0.values) }
                 handlers.forEach { $0(.init(duration: duration, isOngoing: true)) }
                hasTimedOut = true
            case .success:
                semaphoreSuccess = true
                if hasTimedOut {
                    let handlers = observers.withLock { Array($0.values) }
                    handlers.forEach { $0(.init(duration: duration, isOngoing: false)) }
                }
            }
        }
    }
}

extension SentryDefaultRunLoopDelayTracker where T == CFRunLoopObserver {
    convenience init(dependencies: Dependencies) {
        self.init(
            dependencies: dependencies,
            createObserver: CFRunLoopObserverCreateWithHandler,
            addObserver: CFRunLoopAddObserver,
            removeObserver: CFRunLoopRemoveObserver
        )
    }
}
