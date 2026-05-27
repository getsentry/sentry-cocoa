// swiftlint:disable missing_docs
import Foundation

@_spi(Private) @objc public protocol SentryCrashReporter: NSObjectProtocol {
    @objc var crashedLastLaunch: Bool { get }
    @objc var durationFromCrashStateInitToLastCrash: TimeInterval { get }
    @objc var activeDurationSinceLastCrash: TimeInterval { get }
    @objc var isBeingTraced: Bool { get }
    @objc var isSimulatorBuild: Bool { get }
    @objc var isApplicationInForeground: Bool { get }
    @objc var freeMemorySize: UInt64 { get }
    @objc var appMemorySize: UInt64 { get }
    @objc var systemInfo: [String: Any] { get }
    var processInfoWrapper: SentryProcessInfoSource { get }
    @objc func startBinaryImageCache()
    @objc func stopBinaryImageCache()
    @objc func enrichScope(_ scope: Scope)
}
// swiftlint:enable missing_docs
