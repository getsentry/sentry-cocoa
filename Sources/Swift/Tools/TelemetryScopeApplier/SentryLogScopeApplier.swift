// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

/// Required because we need to call this from Objective-C. It's just a wrapper around the TelemetryScopeApplier protocol for Objective-C.
@_spi(Private)
@objc
public protocol SentryLogScopeApplier {
    func applyScope(_ scope: Scope, toLog log: SentryLog) -> SentryLog
}

@_spi(Private)
@objc
@objcMembers
public class SentryDefaultLogScopeApplier: NSObject, SentryLogScopeApplier {
    private let metadata: TelemetryScopeMetadata

    @objc public init(environment: String, releaseName: String?, cacheDirectoryPath: String, sendDefaultPii: Bool) {
        self.metadata = SentryDefaultScopeApplyingMetadata(environment: environment, releaseName: releaseName, cacheDirectoryPath: cacheDirectoryPath, sendDefaultPii: sendDefaultPii)
    }

    @objc public func applyScope(_ scope: Scope, toLog log: SentryLog) -> SentryLog {
        var mutableLog = log
        scope.addAttributesToItem(&mutableLog, metadata: metadata)
        return mutableLog
    }
}

// swiftlint:enable missing_docs
