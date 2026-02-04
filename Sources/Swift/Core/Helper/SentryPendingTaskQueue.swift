@_implementationOnly import _SentryPrivate
import Foundation

/// A thread-safe queue for pending SDK operations that are called before the SDK is fully initialized.
///
/// When the SDK is started on a background thread, there's a window where the SDK is not fully
/// initialized but user code may call methods like `setUser`, `configureScope`, or `addBreadcrumb`.
/// This queue stores those operations and executes them once the SDK is ready.
///
/// See https://github.com/getsentry/sentry-cocoa/issues/6872
@objc(SentryPendingTaskQueue)
@objcMembers
@_spi(Private)
public final class SentryPendingTaskQueue: NSObject {

    private let lock = NSLock()
    private var pendingTasks: [() -> Void] = []

    override public init() {
        super.init()
    }

    /// Adds a task to the pending queue.
    /// The task will be executed when `executePendingTasks` is called.
    /// - Parameter task: A closure containing the operation to be executed.
    @objc public func enqueue(_ task: @escaping () -> Void) {
        lock.withLock {
            pendingTasks.append(task)
        }
        SentrySDKLog.debug("Task enqueued. SDK is not fully initialized yet.")
    }

    /// Executes all pending tasks and clears the queue.
    /// This should be called from the SDK initialization code after the hub is fully set up.
    @objc public func executePendingTasks() {
        let tasks = lock.withLock {
            let tasks = pendingTasks
            pendingTasks = []
            return tasks
        }

        guard !tasks.isEmpty else {
            return
        }

        SentrySDKLog.debug("Executing \(tasks.count) pending task(s) after SDK initialization.")

        for task in tasks {
            task()
        }
    }

    /// Clears all pending tasks without executing them.
    /// This is useful when the SDK is closed.
    @objc public func clearPendingTasks() {
        lock.withLock {
            pendingTasks.removeAll()
        }
    }

#if SENTRY_TEST || SENTRY_TEST_CI
    /// Returns the number of pending tasks.
    /// Used for testing.
    @objc public var pendingTaskCount: Int {
        lock.withLock {
            return pendingTasks.count
        }
    }
#endif
}
