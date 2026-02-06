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
    func addLateRunLoopObserver(handler: @escaping (UUID, TimeInterval) -> Void) -> UUID    
    func removeLateRunLoopObserver(id: UUID)

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
/// which typically indicates an App Hang / Application Not Responding (ANR) condition.
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
/// │  │  • afterWaiting: set loopStartTime, create semaphore, dispatch hang detect  │ │
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
/// │                      BACKGROUND QUEUE (serial)                                   │
/// │  ┌─────────────────────────────────────────────────────────────────────────────┐ │
/// │  │  waitForHangIterative()                                                     │ │
/// │  │  • Blocks the serial queue thread with semaphore.wait(timeout:)             │ │
/// │  │  • On timeout: accesses lateRunLoop directly (already on queue)             │ │
/// │  │  • Observer add/remove blocks are enqueued and execute after hang resolves  │ │
/// │  └─────────────────────────────────────────────────────────────────────────────┘ │
/// │                                                                                  │
/// │  Accesses (serialized on this queue):                                            │
/// │  • lateRunLoop (add/remove/iterate)                                              │
/// │                                                                                  │
/// │  IMPORTANT: waitForHangIterative blocks this queue's thread while waiting.       │
/// │  This means add/removeLateRunLoopObserver blocks are delayed until the hang      │
/// │  resolves (semaphore signaled). This is acceptable because observer              │
/// │  registration during an active hang is not time-critical.                        │
/// │  Do NOT use dispatchSync from within waitForHangIterative — it would deadlock    │
/// │  because the serial queue's current block hasn't returned.                       │
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
/// 1. When run loop starts (afterWaiting): Create a semaphore and dispatch hang detection to background queue
/// 2. If timeout occurs: Report hang and continue waiting (iterative, not recursive to avoid stack overflow)
/// 3. When run loop completes (beforeWaiting): Signal semaphore to stop hang detection
final class SentryDefaultHangTracker<T: RunLoopObserver>: SentryHangTracker {
    private let dateProvider: SentryCurrentDateProvider

    /// Serial background queue used for hang detection and `lateRunLoop` synchronization.
    ///
    /// **Must be a serial queue.** The hang tracker relies on serial execution for two reasons:
    /// 1. `lateRunLoop` dictionary access is serialized by this queue instead of a lock.
    /// 2. `waitForHangIterative` blocks this queue's thread with `semaphore.wait(timeout:)`.
    ///    Using `dispatchSync` from within that blocked thread would deadlock on a serial queue,
    ///    which is why we access `lateRunLoop` directly instead. A concurrent queue would break
    ///    the serialization guarantee and cause data races on `lateRunLoop`.
    ///
    /// **Should be a dedicated queue** (not shared with other SDK components) because
    /// `waitForHangIterative` blocks it for the duration of each hang detection cycle.
    private let queue: SentryDispatchQueueWrapperProtocol

    /// Factory function to create a semaphore.
    private let createSemaphore: CreateSemaphoreFunc

    /// Ratio used to calculate the hang notification threshold in relation to the target FPS of the current window
    ///
    /// A value of 1.5 means that a hang can take up to 50% more time than the expected frame duration to detect a hang.
    ///
    /// - Example: 60 FPS = 16.67ms per frame, so hang threshold = 25ms
    private let hangNotifyThresholdToFPSRatio = 1.5

    /// The hang notification threshold in seconds.
    private let hangNotifyThreshold: TimeInterval

    private let createObserver: CreateObserverFunc<T>
    private let addObserver: AddObserverFunc<T>
    private let removeObserver: RemoveObserverFunc<T>

    private var observer: T?
    
    /// Lock protecting `finishedRunLoop` dictionary.
    ///
    /// This lock is accessed from multiple threads: main thread (observer callbacks) and any thread (add/remove methods).
    private let finishedRunLoopLock = NSLock()
    
    /// Dictionary of finished run loop observers, keyed by their UUID.
    ///
    /// Must be accessed within `finishedRunLoopLock.synchronized` blocks to ensure thread safety.
    private var finishedRunLoop = [UUID: (RunLoopIteration) -> Void]()
    
    /// Start time of the current run loop iteration, set in `afterWaiting` callback.
    ///
    /// Only accessed from main thread (in observer callbacks), so no synchronization needed.
    private var loopStartTime: TimeInterval?
    
    /// Current semaphore used for hang detection of the active run loop iteration.
    ///
    /// This property is ONLY accessed from the main thread:
    /// - Set in `afterWaiting` callback (main thread)
    /// - Read and signaled in `beforeWaiting` callback (main thread)
    private var currentSemaphore: SentryDispatchSemaphore?

    /// Dictionary of late run loop observers, keyed by their UUID.
    ///
    /// This dictionary is only accessed from the background queue,
    /// ensuring serialized access without needing a separate lock.
    private var lateRunLoop = [UUID: (UUID, TimeInterval) -> Void]()

    /// Current hang ID for the active hang detection session.
    ///
    /// This is updated when a new hang detection starts (in afterWaiting callback).
    /// As there can be only be one hang detection session at a time, we only need to track one hang ID.
    private var hangId = UUID()

    /// Initializes the hang tracker.
    ///
    /// - Parameters:
    ///   - applicationProvider: The application provider to get the key window's maximum FPS.
    ///   - dateProvider: The date provider to get the system uptime.
    ///   - queue: A **serial** background queue dedicated to hang detection. Must not be shared
    ///     with other components, as `waitForHangIterative` blocks it during hang detection.
    ///   - createObserver: The function to create a run loop observer.
    ///   - addObserver: The function to add a run loop observer.
    ///   - removeObserver: The function to remove a run loop observer.
    ///   - createSemaphore: The function to create a semaphore.
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
    /// The handler is called on a background thread (since the main thread is blocked during a hang) and receives:
    /// - `id`: A unique identifier for this hang instance
    /// - `interval`: The duration of the hang so far
    ///
    /// - Important: Registration is asynchronous. The UUID is returned immediately, but the handler
    ///   is not active until the async dispatch completes. If a hang occurs between calling this method
    ///   and the async registration completing, the handler will not be called for that hang.
    ///   This trade-off is intentional to avoid potential deadlocks when called from the background queue.
    func addLateRunLoopObserver(handler: @escaping (_ id: UUID, _ interval: TimeInterval) -> Void) -> UUID {
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
            // If this was the last late run loop observer, we can stop the run loop observation entirely.
            self.queue.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
                guard let self = self else {
                    return
                }
                // Double-check after async dispatch to handle race condition where a new observer
                // might have been added between the initial check and this point
                let finishedRunLoopIsEmpty = self.finishedRunLoopLock.synchronized {
                    return self.finishedRunLoop.isEmpty
                }
                // If there are no finished run loop observers, we can stop the run loop observation entirely.
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
    func addFinishedRunLoopObserver(handler: @escaping (_ iteration: RunLoopIteration) -> Void) -> UUID {
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
    /// If this was the last finished run loop observer and there are no late run loop observers,
    /// this will stop the run loop observation entirely to free resources.
    func removeFinishedRunLoopObserver(id: UUID) {
        let isEmpty = finishedRunLoopLock.synchronized {
            finishedRunLoop.removeValue(forKey: id)
            return finishedRunLoop.isEmpty
        }
        // Early return: if other finished observers remain, no need to consider stopping.
        guard isEmpty else {
            return
        }
        // Dispatch to the background queue to safely check lateRunLoop.isEmpty.
        // lateRunLoop is only accessed from this serial queue, so we must be on it to read safely.
        queue.dispatchAsync { [weak self] in
            guard let self = self else {
                return
            }
            // If late observers are still registered, we must keep the run loop observer alive
            // for hang detection. Only stop if both dictionaries are empty.
            guard self.lateRunLoop.isEmpty else {
                return
            }
            self.queue.dispatchAsyncOnMainQueueIfNotMainThread { [weak self] in
                guard let self = self else {
                    return
                }
                // Double-check finishedRunLoop after async dispatch to handle a race condition:
                // a new finished observer might have been added between the initial isEmpty check
                // and this point, which would make stopping incorrect.
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

                    // Dispatch hang detection to the serial background queue.
                    // waitForHangIterative will block this queue's thread with semaphore.wait(timeout:),
                    // which is intentional: the serial queue provides exclusive access to lateRunLoop
                    // without needing dispatchSync (which would deadlock from within the blocked thread).
                    // Any pending add/remove observer blocks execute after the hang resolves.
                    queue.dispatchAsync { [weak self] in
                        self?.waitForHangIterative(semaphore: localSemaphore, started: started, hangId: newHangId)
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
    
    /// Iteratively waits for hang detection timeout, reporting hangs as they occur.
    ///
    /// This method runs on the serial background queue and blocks the queue's thread with
    /// `semaphore.wait(timeout:)`. This is by design:
    /// - The serial queue provides exclusive access to `lateRunLoop` without needing a lock.
    /// - Any pending add/remove observer blocks are enqueued and execute after the hang resolves.
    /// - We MUST NOT call `queue.dispatchSync` from here — it would deadlock because this
    ///   block is the currently-executing block on the serial queue, and `dispatch_sync` waits
    ///   for the queue to be free.
    ///
    /// Algorithm:
    /// 1. Wait for semaphore with timeout = hangNotifyThreshold
    /// 2. If timeout: Report hang and continue waiting (same hang instance)
    /// 3. If signaled: Run loop completed normally, stop detection
    ///
    /// Note: The `afterWaiting` dispatch uses `[weak self]` so `self` can be nil on entry,
    /// but once we enter the method body, `self` is strongly held for the method's duration.
    /// This means self cannot be deallocated mid-loop. If self is deallocated before this
    /// method starts, the optional chaining (`self?.waitForHangIterative`) prevents entry.
    private func waitForHangIterative(semaphore: SentryDispatchSemaphore, started: TimeInterval, hangId: UUID) {
        // This method uses an iterative approach (while loop) instead of recursion to avoid stack overflow
        // when multiple consecutive timeouts occur during a long hang.
        while true {
            let timeout = DispatchTime.now() + DispatchTimeInterval.milliseconds(Int(hangNotifyThreshold * 1_000))
            let result = semaphore.wait(timeout: timeout)
            switch result {
            case .timedOut:
                // Hang detected - report it and continue waiting for the same hang instance.
                //
                // We access lateRunLoop directly here without dispatchSync because this method
                // is already executing on the serial background queue. Using dispatchSync would
                // deadlock: the serial queue considers this block as in-flight, so it won't
                // process a synchronously-enqueued block until this one returns — but this one
                // is waiting for the sync block to complete. Classic serial queue deadlock.
                let handlers = Array(lateRunLoop.values)
                let currentTime = dateProvider.systemUptime()
                handlers.forEach { $0(hangId, currentTime - started) }

            case .success:
                // Semaphore was signaled — run loop iteration completed normally, stop detection.
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
