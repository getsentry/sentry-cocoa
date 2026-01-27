// swiftlint:disable missing_docs
import Foundation

@_spi(Private) @objc public
final class SentryWatchdogTerminationConstants: NSObject {
    @objc public static let ExceptionType: String = "WatchdogTermination"
    @objc public static let ExceptionValue: String = "The OS watchdog terminated your app, possibly because it overused RAM."
    @objc public static let MechanismType: String = "watchdog_termination"
}
// swiftlint:enable missing_docs
