/// Executes a closure while holding an Objective‑C runtime lock on the given object,
/// providing a simple, scoped critical section for synchronizing access to shared state.
///
/// This helper mirrors the behavior of `@synchronized` in Objective‑C by calling
/// `objc_sync_enter(_:)` before running `operation` and guaranteeing a matching
/// `objc_sync_exit(_:)` via `defer`, even if the closure throws or early‑returns.
/// Use it to prevent data races when multiple threads or tasks may access or mutate
/// resources protected by the same lock object.
///
/// Important:
/// - The lock is associated with the identity of `object` (its pointer), not its value.
///   All callers that need to synchronize must pass the exact same object instance.
/// - Avoid locking on highly shared or public objects (e.g., `self` of a widely
///   accessible singleton, or class objects) to reduce the risk of deadlocks.
/// - Keep the critical section as short as possible. Do not perform long‑running work
///   or call out to unknown code while holding the lock.
/// - This function is not `async` and does not suspend. If used from concurrent Swift
///   tasks, ensure all tasks use the same synchronization strategy to avoid priority
///   inversions or deadlocks.
///
/// Thread safety:
/// - Multiple threads calling this function with the same `object` will serialize
///   execution of their `operation` closures.
/// - Calls that use different lock objects proceed independently.
///
/// - Parameters:
///   - object: The object whose associated monitor will be used to guard the critical section.
///             All threads that need mutual exclusion must pass the same object instance.
///   - operation: A closure to execute while holding the lock.
/// - Returns: The value returned by `operation`.
///
/// Example:
/// ```swift
/// final class Counter {
///     private var value = 0
///     private let lock = NSObject()
///
///     func increment() {
///         synchronized(lock) { value += 1 }
///     }
///
///     var current: Int {
///         synchronized(lock) { value }
///     }
/// }
/// ```
func synchronized<T>(_ object: AnyObject, operation: () throws -> T) rethrows -> T {
    objc_sync_enter(object)
    defer { objc_sync_exit(object) }
    return try operation()
}
