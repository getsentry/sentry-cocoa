import Foundation

/// Executes the closure while holding the lock that Objective-C `@synchronized` uses for the object.
///
/// - Parameter object:  The object to lock on.
/// - Parameter closure: The closure to run.
///
/// - Returns:           The value the closure generated.
func synchronized<T>(_ object: AnyObject, _ closure: () throws -> T) rethrows -> T {
    objc_sync_enter(object)
    defer { objc_sync_exit(object) }
    return try closure()
}

/// Be aware that NSLock isn't reentrant, so if you need re-entrancy, use NSRecursiveLock instead.
/// NSLock is slightly faster than NSRecursiveLock, so if you don't need re-entrancy, prefer NSLock.
extension NSLock {
    
    /// Executes the closure while acquiring the lock.
    ///
    /// - Parameter closure: The closure to run.
    ///
    /// - Returns:           The value the closure generated.
    func synchronized<T>(_ closure: () throws -> T) rethrows -> T {
        defer { self.unlock() }
        self.lock()
        return try closure()
    }
}

/// Although this class is only used for tests when adding it, we keep it next to the NSLock extension,
/// as it's highly likely that we have to use it at some point, and we want to keep these two extensions
/// close together.
extension NSRecursiveLock {
    /// Executes the closure while acquiring the lock.
    ///
    /// - Parameter closure: The closure to run.
    ///
    /// - Returns:           The value the closure generated.
    func synchronized<T>(_ closure: () throws -> T) rethrows -> T {
        defer { self.unlock() }
        self.lock()
        return try closure()
    }
}
