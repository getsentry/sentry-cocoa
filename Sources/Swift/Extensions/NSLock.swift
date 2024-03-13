import Foundation

extension NSLock {
    
    /// Executes the closure while acquiring the lock.
    ///
    /// - Parameter closure: The closure to run.
    func synchronized(_ closure: () throws -> Void) rethrows {
        self.lock()
        defer { self.unlock() }
        try closure()
    }
}
