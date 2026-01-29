@_implementationOnly import _SentryPrivate
import Foundation

protocol ScopeApplyingMetadata {
    var environment: String { get }
    var releaseName: String? { get }
    var installationId: String? { get }
}

protocol SentryScopeApplier {
    func applyScope(_ scope: Scope, toLog log: SentryLog) -> SentryLog
    func applyScope(_ scope: Scope, toMetric metric: SentryMetric) -> SentryMetric
}

@_spi(Private)
@objc
@objcMembers
public class SentryScopeApplyingMetadata: NSObject, ScopeApplyingMetadata {
    let environment: String
    let releaseName: String?
    let installationId: String?

    @objc public init(environment: String, releaseName: String?, installationId: String?) {
        self.environment = environment
        self.releaseName = releaseName
        self.installationId = installationId
    }
}

@_spi(Private)
@objc
@objcMembers
public class SentryDefaultScopeApplier: NSObject, SentryScopeApplier {
    private let metadata: SentryScopeApplyingMetadata
    private let sendDefaultPii: Bool

    @objc public init(metadata: SentryScopeApplyingMetadata, sendDefaultPii: Bool) {
        self.metadata = metadata
        self.sendDefaultPii = sendDefaultPii
    }

    @objc public func applyScope(_ scope: Scope, toLog log: SentryLog) -> SentryLog {
        var mutableLog = log
        scope.addAttributesToItem(&mutableLog, sendDefaultPii: sendDefaultPii, metadata: metadata)
        return mutableLog
    }

    public func applyScope(_ scope: Scope, toMetric metric: SentryMetric) -> SentryMetric {
        var mutableMetric = metric
        scope.addAttributesToItem(&mutableMetric, sendDefaultPii: sendDefaultPii, metadata: metadata)
        return mutableMetric
    }
}
