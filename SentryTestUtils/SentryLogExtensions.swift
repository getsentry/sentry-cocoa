import Foundation
@testable @_spi(Private) import Sentry

public enum SentryLog {
    public static func setTestDefaultLogLevel() {
        SentryLogSwiftSupport.configure(true, diagnosticLevel: .debug)
    }
    
    public static func disable() {
        SentryLogSwiftSupport.configure(false, diagnosticLevel: .none)
    }
    
    /// SentryLog uses NSLog internally, which can significantly slow down code because it requires
    /// synchronization. Tests that need code to run fast should can turn off logs to avoid flakiness.
    public static func withoutLogs<T>(_ closure: () throws -> T) rethrows -> T {
        defer { setTestDefaultLogLevel() }
        disable()
        return try closure()
    }
    
}
