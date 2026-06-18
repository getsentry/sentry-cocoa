// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalDebugApi) public final class SentryObjCInternalDebugApi: NSObject {
    internal let wrapped: Box<SentryInternalDebugApi>

    internal init(_ wrapped: SentryInternalDebugApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public var images: [SentryObjCDebugMeta] {
        wrapped.value.images.map { SentryObjCDebugMeta($0) }
    }

    @objc public func imagesForAddresses(_ addresses: [NSNumber]) -> [SentryObjCDebugMeta] {
        let uint64Addresses = addresses.map { $0.uint64Value }
        return wrapped.value.images(forAddresses: uint64Addresses).map { SentryObjCDebugMeta($0) }
    }
}
// swiftlint:enable missing_docs
