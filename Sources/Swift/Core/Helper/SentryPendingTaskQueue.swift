@_implementationOnly import _SentryPrivate
import Foundation

@objc @_spi(Private)
// swiftlint:disable:next missing_docs
public enum SentryPendingTaskType: Int {
    // swiftlint:disable:next missing_docs
    case setUser
}

/// A thread-safe queue for pending SDK operations that are called before the SDK is fully initialized.
///
/// When the SDK is started on a background thread, there's a window where the SDK is not fully
/// initialized but user code may call methods like `setUser`, `configureScope`, or `addBreadcrumb`.
/// This queue stores those operations and executes them once the SDK is ready.
///
/// Tasks have a type that callers can use for deduplication via ``removeAll(type:)`` before
/// enqueueing, ensuring only the most recent value for a given type is applied during execution.
///
/// See https://github.com/getsentry/sentry-cocoa/issues/6872
@objc
@_spi(Private)
public final class SentryPendingTaskQueue: NSObject {

    private struct PendingTask {
        let type: SentryPendingTaskType
        let task: () -> Void
    }

    private let lock = NSRecursiveLock()
    private var pendingTasks: [PendingTask] = []

    override public init() {
        super.init()
    }

    /// Adds a typed task to the pending queue.
    /// - Parameters:
    ///   - task: A closure containing the operation to be executed.
    ///   - type: An enum identifying the task type.
    @objc public func enqueue(_ task: @escaping () -> Void, type: SentryPendingTaskType) {
        lock.synchronized {
            pendingTasks.append(PendingTask(type: type, task: task))
        }
        SentrySDKLog.debug("Typed task '\(type)' enqueued. SDK is not fully initialized yet.")
    }

    /// Removes all pending tasks of the given type without executing them.
    @objc public func removeAll(type: SentryPendingTaskType) {
        lock.synchronized {
            pendingTasks.removeAll { $0.type == type }
        }
    }

    /// Executes all pending tasks and clears the queue.
    /// This should be called from the SDK initialization code after the hub is fully set up.
    @objc public func executePendingTasks() {
        let tasks = lock.synchronized {
            let tasks = pendingTasks
            pendingTasks = []
            return tasks
        }

        guard !tasks.isEmpty else {
            return
        }

        SentrySDKLog.debug("Executing \(tasks.count) pending task(s) after SDK initialization.")

        for entry in tasks {
            entry.task()
        }
    }

    /// Clears all pending tasks without executing them.
    /// This is useful when the SDK is closed.
    @objc public func clearPendingTasks() {
        lock.synchronized {
            pendingTasks.removeAll()
        }
    }

#if SENTRY_TEST || SENTRY_TEST_CI
    /// Returns the number of pending tasks.
    /// Used for testing.
    @objc public var pendingTaskCount: Int {
        lock.synchronized {
            return pendingTasks.count
        }
    }
#endif
}
