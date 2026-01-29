// swiftlint:disable missing_docs
import Foundation

/// Protocol that abstracts DispatchSemaphore for testability.
///
/// This protocol allows us to mock semaphore behavior in unit tests while using
/// real DispatchSemaphore instances in production and integration tests.
protocol SentryDispatchSemaphore {
    /// Creates a new semaphore with the specified initial value.
    init(value: Int)
    
    /// Signals (increments) the semaphore.
    ///
    /// - Returns: The previous value of the semaphore before incrementing.
    func signal() -> Int
    
    /// Waits for the semaphore to be signaled, blocking until signaled or timeout occurs.
    ///
    /// - Parameter timeout: The maximum time to wait for the semaphore to be signaled.
    /// - Returns: `.success` if the semaphore was signaled, `.timedOut` if the timeout expired.
    func wait(timeout: DispatchTime) -> DispatchTimeoutResult
}

extension DispatchSemaphore: SentryDispatchSemaphore {}
// swiftlint:enable missing_docs
