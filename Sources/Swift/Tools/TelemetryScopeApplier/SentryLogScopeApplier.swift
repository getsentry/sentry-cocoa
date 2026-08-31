// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

/// Required because we need to call this from Objective-C. It's just a wrapper around the TelemetryScopeApplier protocol for Objective-C.
@_spi(Private)
@objc
public protocol SentryLogScopeApplier {
    func applyScope(_ scope: Scope, toLog log: SentryLog) -> SentryLog

    /// Merges only the scope's custom attributes into the log, filling keys the log doesn't
    /// already have. Unlike `applyScope(_:toLog:)`, this never touches trace correlation, user,
    /// or other reserved fields — used for the thread-local current scope so it can't clobber
    /// the hub scope's active span.
    func applyScopeAttributes(_ scope: Scope, toLog log: SentryLog) -> SentryLog
}

@_spi(Private)
@objc
@objcMembers
public class SentryDefaultLogScopeApplier: NSObject, SentryLogScopeApplier {
    private let metadata: TelemetryScopeMetadata

    @objc public init(environment: String, releaseName: String?, cacheDirectoryPath: String, shouldAddDefaultUserId: Bool) {
        self.metadata = SentryDefaultScopeApplyingMetadata(environment: environment, releaseName: releaseName, cacheDirectoryPath: cacheDirectoryPath, shouldAddDefaultUserId: shouldAddDefaultUserId)
    }

    @objc public func applyScope(_ scope: Scope, toLog log: SentryLog) -> SentryLog {
        var mutableLog = log
        scope.addAttributesToItem(&mutableLog, metadata: metadata)
        return mutableLog
    }

    @objc public func applyScopeAttributes(_ scope: Scope, toLog log: SentryLog) -> SentryLog {
        let mutableLog = log
        var attributes = mutableLog.attributesDict
        for (key, value) in scope.attributesDict where attributes[key] == nil {
            attributes[key] = value
        }
        mutableLog.attributesDict = attributes
        return mutableLog
    }
}

// swiftlint:enable missing_docs
