#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate
import Foundation
import SentryTestUtilsObjC
import XCTest

extension SentryHubInternal {
    @_spi(Private) @nonobjc public convenience init(
        client: SentryClientInternal?,
        andScope scope: Scope?,
        activeCrashReporterState: SentryCrashReporterState,
        andDispatchQueue dispatchQueue: SentryDispatchQueueWrapper
    ) {
        self.init(
            testClient: client,
            andScope: scope,
            activeCrashReporterState: activeCrashReporterState,
            andDispatchQueue: dispatchQueue
        )
    }

    @_spi(Private) @nonobjc public convenience init(
        client: SentryClientInternal?,
        andScope scope: Scope?,
        activeCrashReporterState: SentryCrashReporterState,
        scopeContextEnricher: SentryScopeContextEnricher,
        andDispatchQueue dispatchQueue: SentryDispatchQueueWrapper
    ) {
        self.init(
            testClient: client,
            andScope: scope,
            activeCrashReporterState: activeCrashReporterState,
            scopeContextEnricher: scopeContextEnricher,
            andDispatchQueue: dispatchQueue
        )
    }

    @_spi(Private) public var session: SentrySession? {
        get {
            guard let object = test_session() else { return nil }
            guard let session = object as? SentrySession else {
                XCTFail("Expected SentrySession, got \(type(of: object))")
                return nil
            }
            return session
        }
        set { test_setSession(newValue) }
    }
}
