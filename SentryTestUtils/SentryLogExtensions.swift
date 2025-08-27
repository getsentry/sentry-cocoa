import Foundation
@_spi(Private) @testable import Sentry

extension SentrySDKLog {

    public static func setDefaultTestLogConfiguration() {
        SentrySDKLog._configure(false, diagnosticLevel: .error)
    }

    /// SentryLog uses NSLog internally, which can significantly slow down code because it requires
    /// synchronization. Use this method sparingly for individual test cases.
    public static func withDebugLogs<T>(_ closure: () throws -> T) rethrows -> T {
        defer { setDefaultTestLogConfiguration() }
        SentrySDKLog._configure(true, diagnosticLevel: .debug)
        return try closure()
    }
    
}
