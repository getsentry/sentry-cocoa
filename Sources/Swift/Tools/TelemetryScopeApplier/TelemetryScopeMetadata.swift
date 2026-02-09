// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation

protocol TelemetryScopeMetadata {
    var environment: String { get }
    var releaseName: String? { get }
    var installationId: String? { get }
    var sendDefaultPii: Bool { get }
}

struct SentryDefaultScopeApplyingMetadata: TelemetryScopeMetadata {
    let environment: String
    let releaseName: String?
    let sendDefaultPii: Bool

    private let cacheDirectoryPath: String

    init(environment: String, releaseName: String?, cacheDirectoryPath: String, sendDefaultPii: Bool) {
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

// swiftlint:enable missing_docs
