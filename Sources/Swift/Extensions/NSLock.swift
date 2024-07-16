import Foundation

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
    
    /// Executes the closure if the flag is false while acquiring the lock.
    /// Updates the flag to true. This can be used as double-check lock.
    ///
    /// - Parameter flag: A flag that will be double check to make sure closure should be invoked.
    /// Only runs the closure if the flag is false, then updates the flag to true.
    /// - Parameter toRun: The closure to run.
    ///
    /// - Returns: The value the closure generated or `nil` if the flag was enabled already.
    func setFlag(_ flag: inout Bool, toRun closure: () throws -> Void) rethrows -> Bool {
        if flag { return false }
        self.lock()
        defer { self.unlock() }
        if flag { return false }
        try closure()
        flag = true
        return true
    }
    
    /// Executes the closure if the flag is true while acquiring the lock.
    /// Updates the flag to false. This can be used as double-check lock.
    ///
    /// - Parameter flag: A flag that will be double check to make sure closure should be invoked.
    /// Only runs the closure if the flag is true, then updates the flag to false.
    /// - Parameter toRun: The closure to run.
    ///
    /// - Returns: The value the closure generated or `nil` if the flag was enabled already.
    func unsetFlag(_ flag: inout Bool, toRun closure: () throws -> Void) rethrows -> Bool {
        if !flag { return false }
        self.lock()
        defer { self.unlock() }
        if !flag { return false }
        try closure()
        flag = false
        return true
    }
        
}
