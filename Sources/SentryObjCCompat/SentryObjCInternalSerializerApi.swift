// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalSerializerApi) public final class SentryObjCInternalSerializerApi: NSObject {
    private let wrapped: Box<SentryInternalSerializerApi>

    internal init(_ wrapped: SentryInternalSerializerApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public func serializeEvent(_ event: SentryObjCEvent) -> [String: Any] {
        wrapped.value.serialize(event: event.wrapped)
    }
}
// swiftlint:enable missing_docs
