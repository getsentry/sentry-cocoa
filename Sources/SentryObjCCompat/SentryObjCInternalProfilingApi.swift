// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

#if !(os(watchOS) || os(tvOS) || os(visionOS))

@objc(SentryObjCInternalProfilingApi) public final class SentryObjCInternalProfilingApi: NSObject {
    private let wrapped: Box<SentryInternalProfilingApi>

    internal init(_ wrapped: SentryInternalProfilingApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public func start(for traceId: SentryObjCId) -> UInt64 {
        wrapped.value.start(for: traceId.wrapped)
    }

    @objc public func collect(between startTime: UInt64, and endTime: UInt64, for traceId: SentryObjCId) -> [String: Any]? {
        wrapped.value.collect(between: startTime, and: endTime, for: traceId.wrapped)
    }

    @objc public func discard(for traceId: SentryObjCId) {
        wrapped.value.discard(for: traceId.wrapped)
    }
}

#endif
// swiftlint:enable missing_docs
