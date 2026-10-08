// swiftlint:disable missing_docs
import Foundation

typealias SentryLogOutput = ((String) -> Void)

/// A note on the thread safety:
/// The methods configure and log don't use synchronization mechanisms, meaning they aren't strictly speaking thread-safe.
/// Still, you can use log from multiple threads. The problem is that when you call configure while
/// calling log from multiple threads, you experience a race condition. It can take a bit until all
/// threads know the new config. As the SDK should only call configure once when starting, we do accept
/// this race condition. Adding locks for evaluating the log level for every log invocation isn't
/// acceptable, as this adds a significant overhead for every log call. Therefore, we exclude SentryLog
/// from the ThreadSanitizer as it produces false positives. The tests call configure multiple times,
/// and the thread sanitizer would surface these race conditions. We accept these race conditions for
/// the log messages in the tests over adding locking for all log messages.
@objc
@_spi(Private) public final class SentrySDKLog: NSObject {

    static private(set) var isDebug = true
    static private(set) var diagnosticLevel = SentryLevel.error

    /**
     * Threshold log level to always log, regardless of the current configuration
     */
    static let alwaysLevel = SentryLevel.fatal
    private static let defaultLogOutput: SentryLogOutput = { print($0) }
    private static var logOutput: SentryLogOutput = defaultLogOutput
    private static var dateProvider: SentryCurrentDateProvider = SentryDefaultCurrentDateProvider()

    static func _configure(_ isDebug: Bool, diagnosticLevel: SentryLevel) {
        self.isDebug = isDebug
        self.diagnosticLevel = diagnosticLevel
    }

    @objc
    public static func log(message: String, andLevel level: SentryLevel) {
        guard willLog(atLevel: level) else { return }
        write(message: message, level: level)
    }

    /// Formats and writes the message without checking ``willLog(atLevel:)``.
    /// Callers must check it exactly once before calling this method.
    private static func write(message: String, level: SentryLevel) {
        // We use the time interval because date format is
        // expensive and we only care about the time difference between the
        // log messages. We don't use system uptime because of privacy concerns
        // see: NSPrivacyAccessedAPICategorySystemBootTime.
        let time = self.dateProvider.date().timeIntervalSince1970
        logOutput("[Sentry] [\(level)] [\(time)] \(message)")
    }

    /**
     * @return @c YES if the current logging configuration will log statements at the current level,
     * @c NO if not.
     */
    @objc
    public static func willLog(atLevel level: SentryLevel) -> Bool {
        if level == .none {
            return false
        }
        if level.rawValue >= alwaysLevel.rawValue {
            return true
        }
        return isDebug && level.rawValue >= diagnosticLevel.rawValue
    }

    /// Sets a custom log output handler. This allows hybrid SDKs (React Native, Flutter, etc.)
    /// to intercept SDK log messages and forward them to their respective consoles.
    /// - Note: Exposed through `SentryInternalApi.setLogOutput` for hybrid SDK consumption.
    /// - Parameter output: A closure to handle log output. If `nil` is passed (which can happen
    ///   from Objective-C callers despite nullability annotations), the default `print` handler is used.
    @objc
    public static func setOutput(_ output: ((String) -> Void)?) {
        // Objective-C callers can pass nil at runtime despite NS_ASSUME_NONNULL annotations.
        // Fall back to default print handler to prevent crashes when logging.
        logOutput = output ?? defaultLogOutput
    }

    #if SENTRY_TEST || SENTRY_TEST_CI

        static func getOutput() -> SentryLogOutput {
            return logOutput
        }

        static func setDateProvider(_ dateProvider: SentryCurrentDateProvider) {
            self.dateProvider = dateProvider
        }

    #endif
}

extension SentrySDKLog {
    /// Formats the call site into the message and writes it.
    ///
    /// Never inlined, so the formatting exists once instead of being copied into every
    /// call site of the level methods below.
    @inline(never)
    private static func log(level: SentryLevel, message: String, file: String, line: Int) {
        let path = file as NSString
        let fileName = (path.lastPathComponent as NSString).deletingPathExtension
        write(message: "[\(fileName):\(line)] \(message)", level: level)
    }

    // The level methods take the message as an autoclosure so it is only built when it gets
    // logged. They are always inlined because, when they are not, the optimizer instead
    // specializes each of them for every call site to inline the closure there, which emitted
    // one copy of the method per log statement and grew the SDK binary noticeably.
    @inline(__always)
    static func debug(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        guard willLog(atLevel: .debug) else { return }
        log(level: .debug, message: message(), file: file, line: line)
    }

    @inline(__always)
    static func info(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        guard willLog(atLevel: .info) else { return }
        log(level: .info, message: message(), file: file, line: line)
    }

    @inline(__always)
    static func warning(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        guard willLog(atLevel: .warning) else { return }
        log(level: .warning, message: message(), file: file, line: line)
    }

    @inline(__always)
    static func error(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        guard willLog(atLevel: .error) else { return }
        log(level: .error, message: message(), file: file, line: line)
    }

    static func fatal(_ message: String, file: String = #file, line: Int = #line) {
        log(level: .fatal, message: message, file: file, line: line)
    }
}
// swiftlint:enable missing_docs
