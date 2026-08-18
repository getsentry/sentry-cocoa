// swiftlint:disable missing_docs
import Foundation

@_spi(Private) @objc public protocol SentryCrashReporterState: NSObjectProtocol {
    @objc var installed: Bool { get }
    @objc var crashedLastLaunch: Bool { get }
}

@_spi(Private) @objc public protocol SentryCrashReporter: SentryCrashReporterState {
    @objc var durationFromCrashStateInitToLastCrash: TimeInterval { get }
    @objc var activeDurationSinceLastCrash: TimeInterval { get }
    @objc var isSimulatorBuild: Bool { get }
    @objc var freeMemorySize: UInt64 { get }
    @objc var appMemorySize: UInt64 { get }
    @objc var systemInfo: [String: Any] { get }
    @objc var introspectMemory: Bool { get set }
    var processInfoWrapper: SentryProcessInfoSource { get }
    @objc func enrichScope(_ scope: Scope)
}
// swiftlint:enable missing_docs
