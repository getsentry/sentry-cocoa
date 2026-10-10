#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate
import Foundation
import SentryTestUtilsObjC
import XCTest

extension TraceContext {
    @nonobjc public convenience init?(scope: Scope, options: Options) {
        self.init(testScope: scope, testOptions: options)
    }

    @_spi(Private) @nonobjc public convenience init?(tracer: SentryTracer, scope: Scope?, options: Options) {
        self.init(testTracer: tracer, scope: scope, testOptions: options)
    }

    @nonobjc public convenience init(trace: SentryId, options: Options, replayId: String?) {
        self.init(testTrace: trace, testOptions: options, replayId: replayId)
    }
}
