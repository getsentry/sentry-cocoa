import Foundation

extension SentryLog {
    public static func setTestDefaultLogLevel() {
        SentryLog.configure(true, diagnosticLevel: .debug)
    }
    
    public static func disable() {
        SentryLog.configure(false, diagnosticLevel: .none)
    }
    
    /// SentryLog uses NSLog internally, which can significantly slow down code because it requires
    /// synchronization. Tests that need code to run fast should can turn off logs to avoid flakiness.
    public static func withOutLogs<T>(_ closure: () throws -> T) rethrows -> T {
        defer { setTestDefaultLogLevel() }
        disable()
        return try closure()
    }
    
}
