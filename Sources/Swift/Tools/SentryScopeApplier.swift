// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

protocol SentryScopeApplyingMetadata {
    var environment: String { get }
    var releaseName: String? { get }
    var installationId: String? { get }
    var sendDefaultPii: Bool { get }
}

class SentryDefaultScopeApplyingMetadata: SentryScopeApplyingMetadata {
    let environment: String
    let releaseName: String?
    private let cacheDirectoryPath: String
    let sendDefaultPii: Bool

    public init(environment: String, releaseName: String?, cacheDirectoryPath: String, sendDefaultPii: Bool) {
        self.environment = environment
        self.releaseName = releaseName
        self.cacheDirectoryPath = cacheDirectoryPath
        self.sendDefaultPii = sendDefaultPii
    }

    /// Returns the installation ID lazily to avoid file I/O on the calling thread.
    ///
    /// The SDK stores the installation ID in a file. The first call requires file I/O.
    /// By returning it lazily via a computed property, we defer this I/O until the
    /// installation ID is actually accessed during scope application, rather than
    /// blocking the thread that creates this metadata object.
    var installationId: String? {
        return SentryInstallation.cachedId(withCacheDirectoryPath: cacheDirectoryPath)
    }
}

@_spi(Private)
@objc
public protocol SentryLogScopeApplier {
    func applyScope(_ scope: Scope, toLog log: SentryLog) -> SentryLog
}

@_spi(Private)
@objc
@objcMembers
public class SentryDefaultLogScopeApplier: NSObject, SentryLogScopeApplier {
    private let metadata: SentryScopeApplyingMetadata

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
