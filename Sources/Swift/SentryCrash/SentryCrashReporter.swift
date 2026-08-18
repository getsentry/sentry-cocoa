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
    @objc var introspectMemory: Bool { get set }
}
// swiftlint:enable missing_docs
