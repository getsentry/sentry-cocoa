// swiftlint:disable missing_docs
internal import _SentryPrivate
import Foundation

/// Required because we need to call this from Objective-C. It's just a wrapper around the TelemetryScopeApplier protocol for Objective-C.
@_spi(Private)
@objc
public protocol SentryLogScopeApplier {
    /// Applies the scope to the log. Custom attribute precedence: log > current scope > global
    /// scope. Trace correlation, user, and the other reserved attributes always come from
    /// `scope`, so the thread-local current scope can't clobber the hub scope's active span.
    func applyScope(_ scope: Scope, currentScope: Scope?, toLog log: SentryLog) -> SentryLog
}

@_spi(Private)
@objc
@objcMembers
public class SentryDefaultLogScopeApplier: NSObject, SentryLogScopeApplier {
    private let metadata: TelemetryScopeMetadata

    @objc public init(environment: String, releaseName: String?, cacheDirectoryPath: String, shouldAddDefaultUserId: Bool) {
        self.metadata = SentryDefaultScopeApplyingMetadata(environment: environment, releaseName: releaseName, cacheDirectoryPath: cacheDirectoryPath, shouldAddDefaultUserId: shouldAddDefaultUserId)
    }

    @objc public func applyScope(_ scope: Scope, currentScope: Scope?, toLog log: SentryLog) -> SentryLog {
        var mutableLog = log
        scope.addAttributesToItem(&mutableLog, metadata: metadata, currentScope: currentScope)
        return mutableLog
    }
}

// swiftlint:enable missing_docs
