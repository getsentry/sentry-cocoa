// swiftlint:disable missing_docs
import Foundation

@_spi(Private) @objc public protocol SentryCrashReporterState: NSObjectProtocol {
    @objc var installed: Bool { get }
    @objc var crashedLastLaunch: Bool { get }
}

// swiftlint:enable missing_docs
