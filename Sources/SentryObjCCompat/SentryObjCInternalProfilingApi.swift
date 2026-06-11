// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

#if SENTRY_TARGET_PROFILING_SUPPORTED

@objc(SentryObjCInternalProfilingApi) public final class SentryObjCInternalProfilingApi: NSObject {
    internal let wrapped: SentryInternalProfilingApi

    internal init(_ wrapped: SentryInternalProfilingApi) {
        self.wrapped = wrapped
    }

    @objc public func start(forTraceId traceId: SentryObjCId) -> UInt64 {
        wrapped.start(for: traceId.wrapped)
    }

    @objc public func collectBetween(_ startSystemTime: UInt64, and endSystemTime: UInt64, forTraceId traceId: SentryObjCId) -> [String: Any]? {
        wrapped.collect(between: startSystemTime, and: endSystemTime, for: traceId.wrapped)
    }

    @objc public func discard(forTraceId traceId: SentryObjCId) {
        wrapped.discard(for: traceId.wrapped)
    }
}

#endif
// swiftlint:enable missing_docs
