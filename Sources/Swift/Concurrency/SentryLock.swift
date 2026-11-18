/// A lock that serializes access to something it doesn't hold itself, such as a file.
///
/// Use ``SentryMutex`` when the lock protects a value, so the value can only be reached while the
/// lock is held. Like ``SentryMutex``, the lock isn't recursive.
struct SentryLock {
    private let mutex = SentryMutex<Void>(())

    /// Calls the given closure after acquiring the lock and then releases it.
    ///
    /// - Warning: Calling `withLock` again within the closure is undefined, as it is for
    ///   ``SentryMutex/withLock(_:)``.
    ///
    /// - Returns: The return value, if any, of the `body` closure parameter.
    func withLock<Result>(_ body: () throws -> Result) rethrows -> Result {
        try mutex.withLock { _ in try body() }
    }

    /// Calls the given closure if the lock can be acquired without waiting.
    ///
    /// - Returns: The return value, if any, of the `body` closure parameter, or `nil` if the lock
    ///   couldn't be acquired.
    func withLockIfAvailable<Result>(_ body: () throws -> Result) rethrows -> Result? {
        try mutex.withLockIfAvailable { _ in try body() }
    }
}

extension SentryLock: Sendable {}
