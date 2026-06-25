import os

/// A synchronization primitive that protects shared mutable state via
/// mutual exclusion.
///
/// The `SentryMutex` type offers non-recursive exclusive access to the state
/// it is protecting by blocking threads attempting to acquire the lock.
/// Only one execution context at a time has access to the value stored
/// within the `SentryMutex`, requiring callers to acquire the lock before
/// reading or writing the protected value.
///
/// An example use of `SentryMutex` in a class used simultaneously by many
/// threads protecting a `Dictionary` value:
///
///     class Manager {
///       let cache = SentryMutex<[Key: Resource]>([:])
///
///       func saveResource(_ resource: Resource, as key: Key) {
///         cache.withLock {
///           $0[key] = resource
///         }
///       }
///     }
///
/// Similar in spirit to `OSAllocatedUnfairLock` (iOS 16+/macOS 13+),
/// using `os_unfair_lock` for older deployment targets.
struct SentryMutex<Value> {

    private final class Storage {
        let lock: UnsafeMutablePointer<os_unfair_lock_s>
        var value: Value

        init(_ value: Value) {
            self.lock = .allocate(capacity: 1)
            self.lock.initialize(to: os_unfair_lock_s())
            self.value = value
        }

        deinit {
            self.lock.deinitialize(count: 1)
            self.lock.deallocate()
        }
    }

    private let storage: Storage

    /// Initializes a value of this mutex with the given initial state.
    ///
    /// - Parameter initialValue: The initial value to give to the mutex.
    init(_ initialValue: Value) {
        storage = Storage(initialValue)
    }

    /// Calls the given closure after acquiring the lock and then releases
    /// ownership.
    ///
    /// - Warning: Recursive calls to `withLock` within the
    ///   closure parameter has behavior that is platform dependent.
    ///   Some platforms may choose to panic the process, deadlock,
    ///   or leave this behavior unspecified. This will never
    ///   reacquire the lock however.
    ///
    /// - Parameter body: A closure with a parameter of `Value`
    ///   that has exclusive access to the value being stored within
    ///   this mutex. This closure is considered the critical section
    ///   as it will only be executed once the calling thread has
    ///   acquired the lock.
    ///
    /// - Returns: The return value, if any, of the `body` closure parameter.
    func withLock<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result {
        os_unfair_lock_lock(storage.lock)
        defer { os_unfair_lock_unlock(storage.lock) }
        return try body(&storage.value)
    }

    /// Attempts to acquire the lock and then calls the given closure if
    /// successful.
    ///
    /// If the calling thread was successful in acquiring the lock, the
    /// closure will be executed and then immediately after it will
    /// release ownership of the lock. If we were unable to acquire the
    /// lock, this will return `nil`.
    ///
    /// - Parameter body: A closure with a parameter of `Value`
    ///   that has exclusive access to the value being stored within
    ///   this mutex. This closure is considered the critical section
    ///   as it will only be executed if the calling thread acquires
    ///   the lock.
    ///
    /// - Returns: The return value, if any, of the `body` closure parameter
    ///   or nil if the lock couldn't be acquired.
    func withLockIfAvailable<Result>(_ body: (inout Value) throws -> Result) rethrows -> Result? {
        guard os_unfair_lock_trylock(storage.lock) else { return nil }
        defer { os_unfair_lock_unlock(storage.lock) }
        return try body(&storage.value)
    }
}

extension SentryMutex: @unchecked Sendable {}
