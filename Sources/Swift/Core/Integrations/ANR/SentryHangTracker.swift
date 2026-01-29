// swiftlint:disable file_length
@_implementationOnly import _SentryPrivate
#if canImport(UIKit) && !SENTRY_NO_UIKIT
import UIKit
#endif

/// Represents a completed run loop iteration with its start and end times.
struct RunLoopIteration {
    let startTime: TimeInterval
    let endTime: TimeInterval
}

protocol SentryHangTracker {
    // The callback must be called on a background thread, because the main thread is blocked
    func addLateRunLoopObserver(handler: @escaping (UUID, TimeInterval) -> Void) -> UUID
    
    func removeLateRunLoopObserver(id: UUID)

    // The callback is always called on the main thread
    func addFinishedRunLoopObserver(handler: @escaping (RunLoopIteration) -> Void) -> UUID
    
    func removeFinishedRunLoopObserver(id: UUID)
}

protocol RunLoopObserver { }
extension CFRunLoopObserver: RunLoopObserver { }

typealias CreateObserverFunc<T> = (_ allocator: CFAllocator?, _ activities: CFOptionFlags, _ repeats: Bool, _ order: CFIndex, _ block: ((T?, CFRunLoopActivity) -> Void)?) -> T?
typealias AddObserverFunc<T> = (_ rl: CFRunLoop?, _ observer: T?, _ mode: CFRunLoopMode?) -> Void
typealias RemoveObserverFunc<T> = (_ rl: CFRunLoop?, _ observer: T?, _ mode: CFRunLoopMode?) -> Void
typealias CreateSemaphoreFunc = (_ value: Int) -> SentryDispatchSemaphore

/// Tracks main thread hangs by observing the run loop and detecting when it takes too long to complete.
///
/// This module provides hang detection for the main thread by observing the CFRunLoop.
/// It detects when the main thread is blocked for longer than the configured threshold,
/// which typically indicates an Application Not Responding (ANR) condition.
///
/// Key Concepts:
/// - Run Loop Iterations: The main thread processes events in discrete iterations.
///   Each iteration starts with `afterWaiting` and ends with `beforeWaiting`.
/// - Hang Detection: If a run loop iteration takes longer than `hangNotifyThreshold`,
///   it's considered a hang and observers are notified.
/// - Thread Safety: Hang detection runs on a background thread (since main thread is blocked),
///   while run loop observation happens on the main thread.
///
/// Thread Model:
///
/// ┌──────────────────────────────────────────────────────────────────────────────────┐
/// │                              MAIN THREAD                                         │
/// │  ┌─────────────────────────────────────────────────────────────────────────────┐ │
/// │  │  CFRunLoopObserver Callbacks                                                │ │
/// │  │  • afterWaiting: set loopStartTime, create semaphore, start wait            │ │
/// │  │  • beforeWaiting: signal semaphore, notify finishedRunLoop                  │ │
/// │  └─────────────────────────────────────────────────────────────────────────────┘ │
/// │                                    │                                             │
/// │  Accesses without lock:            │   Accesses WITH lock:                       │
/// │  • observer                        │   • finishedRunLoop (copy handlers)         │
/// │  • currentSemaphore                │                                             │
/// │  • loopStartTime                   │                                             │
/// │  • hangId                          │                                             │
/// └────────────────────────────────────┼─────────────────────────────────────────────┘
///                                      │
///                           DispatchSemaphore.signal()
///                                      │
///                                      ▼
/// ┌──────────────────────────────────────────────────────────────────────────────────┐
/// │                            BACKGROUND QUEUE                                      │
/// │  ┌─────────────────────────────────────────────────────────────────────────────┐ │
/// │  │  waitForHangIterative()                                                     │ │
/// │  │  • Semaphore.wait(timeout:) in while loop                                   │ │
/// │  │  • On timeout: notify lateRunLoop handlers                                  │ │
/// │  └─────────────────────────────────────────────────────────────────────────────┘ │
/// │                                                                                  │
/// │  Accesses (serialized on this queue):                                            │
/// │  • lateRunLoop (add/remove/iterate)                                              │
/// └──────────────────────────────────────────────────────────────────────────────────┘
///                                      │
///                                      ▼
/// ┌──────────────────────────────────────────────────────────────────────────────────┐
/// │                               ANY THREAD                                         │
/// │  Public API calls:                                                               │
/// │  • addFinishedRunLoopObserver() - LOCK REQUIRED                                  │
/// │  • removeFinishedRunLoopObserver() - LOCK REQUIRED                               │
/// │  • addLateRunLoopObserver() - dispatches to background queue                     │
/// │  • removeLateRunLoopObserver() - dispatches to background queue                  │
/// └──────────────────────────────────────────────────────────────────────────────────┘
///
/// Hang Detection Algorithm:
/// 1. When run loop starts (afterWaiting): Create a semaphore and start background thread waiting for timeout
/// 2. If timeout occurs: Report hang and continue waiting (iterative, not recursive to avoid stack overflow)
/// 3. When run loop completes (beforeWaiting): Signal semaphore to stop hang detection
final class SentryDefaultHangTracker<T: RunLoopObserver>: SentryHangTracker {
    private let dateProvider: SentryCurrentDateProvider

    /// This queue is used to detect main thread hangs, they need to be detected on a background thread since the main thread is hanging.
    private let queue: SentryDispatchQueueWrapperProtocol

    /// Ratio used to calculate the hang notification threshold in relation to the target FPS of the current window
    private let hangNotifyThresholdToFPSRatio = 1.5
    private let hangNotifyThreshold: TimeInterval

    private let createObserver: CreateObserverFunc<T>
    private let addObserver: AddObserverFunc<T>
    private let removeObserver: RemoveObserverFunc<T>
    private let createSemaphore: CreateSemaphoreFunc

    private var observer: T?
    
    /// Lock protecting `finishedRunLoop` dictionary.
    /// This lock is accessed from multiple threads: main thread (observer callbacks) and any thread (add/remove methods).
    private let finishedRunLoopLock = NSLock()
    
    /// Dictionary of finished run loop observers, keyed by their UUID.
    /// Must be accessed within `finishedRunLoopLock.synchronized` blocks to ensure thread safety.
    private var finishedRunLoop = [UUID: (RunLoopIteration) -> Void]()
    
    /// Start time of the current run loop iteration, set in `afterWaiting` callback.
    /// Only accessed from main thread (in observer callbacks), so no synchronization needed.
    private var loopStartTime: TimeInterval?
    
    /// Current semaphore used for hang detection of the active run loop iteration.
    ///
    /// Thread Safety: This property is ONLY accessed from the main thread:
    /// - Set in `afterWaiting` callback (main thread)
    /// - Read and signaled in `beforeWaiting` callback (main thread)
    /// - Background thread receives its own copy via parameter, so no synchronization needed
    ///
    /// Why this is safe: The CFRunLoop observer callbacks always execute on the main thread's run loop,
    /// so there's no race condition between setting and signaling the semaphore.
    private var currentSemaphore: SentryDispatchSemaphore?

    /// Dictionary of late run loop observers, keyed by their UUID.
    /// This dictionary is only accessed from the background queue via `queue.dispatchSync`,
    /// ensuring serialized access without needing a separate lock.
    private var lateRunLoop = [UUID: (UUID, TimeInterval) -> Void]()

    /// Current hang ID for the active hang detection session.
    /// This is updated when a new hang detection starts (in afterWaiting callback).
    private var hangId = UUID()

    init(
        applicationProvider: ApplicationProvider,
        dateProvider: SentryCurrentDateProvider,
        queue: SentryDispatchQueueWrapperProtocol,
        createObserver: @escaping CreateObserverFunc<T>,
        addObserver: @escaping AddObserverFunc<T>,
        removeObserver: @escaping RemoveObserverFunc<T>,
        createSemaphore: @escaping CreateSemaphoreFunc = { DispatchSemaphore(value: $0) }
    ) {
        self.dateProvider = dateProvider
        self.queue = queue

        self.createObserver = createObserver
        self.addObserver = addObserver
        self.removeObserver = removeObserver
        self.createSemaphore = createSemaphore

        // Derive the target frames-per-second ratio from the active scene's key window with a ratio used to correct slow frames
        //
        // Platform-specific initialization:
        // - On UIKit platforms (iOS, tvOS): Query the key window's maximum FPS to adapt
        //   to ProMotion displays (120Hz) or standard displays (60Hz)
        // - On non-UIKit platforms (macOS): Default to 60 FPS
        //
        // The hang threshold is calculated as: (1.0 / maxFPS) * 1.5
        // This means a hang is detected if a run loop iteration takes longer than 1.5 frame durations.
        // For example: 60 FPS = 16.67ms per frame, so hang threshold = 25ms
        #if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
        let application = applicationProvider.application()
        let windows = application?.connectedScenes.flatMap { ($0 as? UIWindowScene)?.windows ?? [] } ?? []
        let keyWindow = windows.first { $0.isKeyWindow }
        let maxFPS = Double(keyWindow?.screen.maximumFramesPerSecond ?? 60)
        #else
        let maxFPS = 60.0
        #endif

        let expectedFrameDuration = 1.0 / maxFPS
        hangNotifyThreshold = expectedFrameDuration * hangNotifyThresholdToFPSRatio
    }
    
    /// Adds an observer that gets called when a hang is detected.
    ///
    /// The handler is called on a background thread (since the main thread is blocked during a hang).
    /// The handler receives:
    /// - `UUID`: A unique identifier for this hang instance
    /// - `TimeInterval`: The duration of the hang so far
    ///
    /// - Important: Registration is asynchronous. The UUID is returned immediately, but the handler
    ///   is not active until the async dispatch completes. If a hang occurs between calling this method
    ///   and the async registration completing, the handler will not be called for that hang.
    ///   This trade-off is intentional to avoid potential deadlocks when called from the background queue.
    func addLateRunLoopObserver(handler: @escaping (UUID, TimeInterval) -> Void) -> UUID {
        let id = UUID()
        queue.dispatchAsync { [weak self] in
            guard let self = self else {
                return
            }
            self.lateRunLoop[id] = handler
            self.queue.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
                guard let self = self else {
                    return
                }
                self.startIfNecessary()
            }
        }
        return id
    }
    
    /// Removes a late run loop observer.
    ///
    /// If this was the last late run loop observer and there are no finished run loop observers,
    /// this will stop the run loop observation entirely to free resources.
    ///
    /// - Important: Removal is asynchronous. The method returns immediately, but the handler
    ///   is not removed until the async dispatch completes. If a hang occurs between calling this
    ///   method and the async removal completing, the handler may still be called for that hang.
    ///   This trade-off is intentional to avoid potential deadlocks when called from the background queue.
    func removeLateRunLoopObserver(id: UUID) {
        queue.dispatchAsync { [weak self] in
            guard let self = self else {
                return
            }
            self.lateRunLoop.removeValue(forKey: id)
            guard lateRunLoop.isEmpty else {
                return
            }
            self.queue.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
                guard let self = self else {
                    return
                }
                // Double-check after async dispatch to handle race condition where a new observer
                // might have been added between the initial check and this point
                let finishedRunLoopIsEmpty = self.finishedRunLoopLock.synchronized {
                    return self.finishedRunLoop.isEmpty
                }
                if finishedRunLoopIsEmpty {
                    self.stop()
                }
            }
        }
    }
    
    /// Adds an observer that gets called when a run loop iteration completes.
    ///
    /// The handler is always called on the main thread and receives a `RunLoopIteration` containing
    /// the start and end time of the completed iteration.
    func addFinishedRunLoopObserver(handler: @escaping (RunLoopIteration) -> Void) -> UUID {
        let id = UUID()
        // Synchronize access to the `finishedRunLoop` dictionary to prevent race conditions when observers are added/removed concurrently or during iteration.
        finishedRunLoopLock.synchronized {
            finishedRunLoop[id] = handler
        }
        startIfNecessary()
        return id
    }
    
    /// Removes a finished run loop observer.
    ///
    /// - Important: Removal is asynchronous. The method returns immediately, but the handler
    ///   is not removed until the async dispatch completes. If a hang occurs between calling this
    ///   method and the async removal completing, the handler may still be called for that hang.
    ///   This trade-off is intentional to avoid potential deadlocks when called from the background queue.
    func removeFinishedRunLoopObserver(id: UUID) {
        // This method implements a double-check pattern to handle a race condition where:
        // 1. Thread A removes the last observer and checks `finishedRunLoop.isEmpty == true`
        // 2. Thread B adds a new observer before Thread A's async dispatch completes
        // 3. Thread A's async dispatch would incorrectly stop tracking
        //
        // We check `isEmpty` before dispatching to the main thread, then double-check after the async dispatch completes to handle the race condition.
        let isEmpty = finishedRunLoopLock.synchronized {
            finishedRunLoop.removeValue(forKey: id)
            return finishedRunLoop.isEmpty
        }
        guard isEmpty else {
            return
        }
        queue.dispatchAsync { [weak self] in
            guard let self = self else {
                return
            }
            self.queue.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
                guard let self = self else {
                    return
                }
                // Double-check after async dispatch to handle race condition where a new observer
                // might have been added between the initial check and this point
                let stillEmpty = finishedRunLoopLock.synchronized {
                    return self.finishedRunLoop.isEmpty
                }
                
                guard stillEmpty else {
                    return
                }
                self.stop()
            }
        }
    }

    /// Starts run loop observation if not already running on the main thread.
    ///
    /// It creates a CFRunLoopObserver that monitors two activities:
    /// - `afterWaiting`: Run loop starts processing (beginning of iteration)
    /// - `beforeWaiting`: Run loop completes processing (end of iteration)
    private func startIfNecessary() {
        // This method should be called on the main thread, so we dispatch to the main queue to avoid potential misuse.
        queue.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
            guard let self = self else { return }
            guard observer == nil else { return }

            let observer = createObserver(nil, CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.afterWaiting.rawValue, true, CFIndex(INT_MAX)) { [weak self] _, activity in
                guard let self = self else { return }

                let currentTime = dateProvider.systemUptime()
                switch activity {
                case .beforeWaiting:
                    // This activity occurs when the run loop is about to go to sleep, meaning it has
                    // finished processing all current events and is waiting for new events to arrive.
                    // This marks the end of a run loop iteration.

                    // Run loop iteration completed - signal semaphore to stop hang detection
                    // This is safe because both beforeWaiting and afterWaiting execute on the main thread,
                    // so there's no race condition when accessing currentSemaphore
                    _ = self.currentSemaphore?.signal()
                    self.currentSemaphore = nil

                    if let loopStartTime = self.loopStartTime {
                        // Create a copy of handlers to avoid modification during iteration.
                        // This prevents crashes if an observer removes itself or another observer is
                        // removed while we're iterating. We copy the handlers array while holding the lock,
                        // then iterate over the copy outside the lock to avoid holding the lock during
                        // handler execution (which could be slow or cause deadlocks).
                        let handlers = self.finishedRunLoopLock.synchronized {
                            return Array(self.finishedRunLoop.values)
                        }

                        for handler in handlers {
                            handler(RunLoopIteration(startTime: loopStartTime, endTime: currentTime))
                        }
                    }
                case .afterWaiting:
                    // This activity occurs when the run loop wakes up after sleeping, meaning new events
                    // have arrived and the run loop is about to start processing them.
                    // This marks the beginning of a new run loop iteration.

                    // Run loop iteration started - begin hang detection
                    let started = currentTime
                    self.loopStartTime = currentTime

                    // Generate hangId immediately when hang detection starts, not after timeout.
                    // This ensures each hang instance has a unique ID from the start, even if multiple
                    // timeouts occur before the first completes.
                    let newHangId = UUID()
                    self.hangId = newHangId

                    let localSemaphore = self.createSemaphore(0)
                    // Store semaphore for beforeWaiting to signal (main thread only, no sync needed)
                    // The semaphore is used to signal that the run loop iteration completed normally,
                    // which stops the hang detection timeout.
                    self.currentSemaphore = localSemaphore
                    queue.dispatchAsync { [weak self] in
                        guard let self = self else { return }
                        self.waitForHang(semaphore: localSemaphore, started: started, hangId: newHangId)
                    }
                default:
                    fatalError()
                }
            }
            self.observer = observer
            self.addObserver(CFRunLoopGetMain(), observer, .commonModes)
        }
    }
    
    /// Stops run loop observation.
    ///
    /// Removing the observer stops all hang detection and run loop iteration callbacks.
    private func stop() {
        // The removal of the observer must be done on the main thread, so we dispatch to the main queue to avoid potential misuse.
        queue.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
            guard let self = self else { return }
            self.removeObserver(CFRunLoopGetMain(), self.observer, .commonModes)
            self.observer = nil
        }
    }
    
    /// Initiates hang detection on the background queue.
    ///
    /// This method dispatches to the background queue where the actual hang detection happens.
    /// The semaphore is used to detect when the run loop iteration completes (signaled from main thread).
    private func waitForHang(semaphore: SentryDispatchSemaphore, started: TimeInterval, hangId: UUID) {
        queue.dispatchAsync { [weak self] in
            guard let self = self else { return }
            self.waitForHangIterative(semaphore: semaphore, started: started, hangId: hangId)
        }
    }
    
    /// Iteratively waits for hang detection timeout, reporting hangs as they occur.
    ///
    /// Algorithm:
    /// 1. Wait for semaphore with timeout = hangNotifyThreshold
    /// 2. If timeout: Report hang and continue waiting (same hang instance)
    /// 3. If signaled: Run loop completed normally, stop detection
    /// 4. If self is deallocated: Exit loop to prevent infinite waiting
    private func waitForHangIterative(semaphore: SentryDispatchSemaphore, started: TimeInterval, hangId: UUID) {
        let currentStarted = started
        let currentHangId = hangId

        // This method uses an iterative approach (while loop) instead of recursion to avoid stack overflow
        // when multiple consecutive timeouts occur during a long hang.
        while true {
            let timeout = DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(hangNotifyThreshold * 1_000))
            let result = semaphore.wait(timeout: timeout)
            switch result {
            case .timedOut:
                // Hang detected - report it and continue waiting for the same hang instance
                // Use the hangId passed in (generated when hang detection started in afterWaiting)
                var shouldContinue = false
                queue.dispatchSync { [weak self] in
                    // If the hang tracker is deallocated while this method is running, the semaphore will never
                    // be signaled (since `beforeWaiting` won't run). We check `self` on each timeout and exit
                    // the loop if deallocated, preventing the background thread from being blocked forever.
                    guard let self = self else {
                        // Self was deallocated - we'll exit the loop after this block
                        return
                    }
                    shouldContinue = true
                    let handlers = Array(self.lateRunLoop.values)
                    let currentTime = self.dateProvider.systemUptime()
                    handlers.forEach { $0(currentHangId, currentTime - currentStarted) }
                }
                // If self was deallocated, exit the loop to prevent infinite waiting.
                // The semaphore will never be signaled since beforeWaiting won't run.
                if !shouldContinue {
                    return
                }
                // Continue waiting - the semaphore will be signaled when beforeWaiting occurs,
                // indicating the run loop iteration completed
            case .success:
                // Semaphore was signaled - run loop iteration completed normally, stop detection
                return
            }
        }
    }
}

extension SentryDefaultHangTracker where T == CFRunLoopObserver {
    /// Convenience initializer for the concrete CFRunLoopObserver type.
    ///
    /// This initializer provides a simpler API by using the standard CFRunLoop observer functions
    /// instead of requiring callers to pass function pointers. It's used in production code where
    /// we work with real CFRunLoopObserver instances.
    convenience init(
        applicationProvider: ApplicationProvider,
        dateProvider: SentryCurrentDateProvider,
        queue: SentryDispatchQueueWrapper,
        createSemaphore: @escaping CreateSemaphoreFunc = { DispatchSemaphore(value: $0) }
    ) {
        self.init(
            applicationProvider: applicationProvider,
            dateProvider: dateProvider,
            queue: queue,
            createObserver: CFRunLoopObserverCreateWithHandler,
            addObserver: CFRunLoopAddObserver,
            removeObserver: CFRunLoopRemoveObserver,
            createSemaphore: createSemaphore
        )
    }
}
// swiftlint:enable file_length
