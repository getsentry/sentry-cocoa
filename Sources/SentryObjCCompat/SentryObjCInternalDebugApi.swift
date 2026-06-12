// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalDebugApi) public final class SentryObjCInternalDebugApi: NSObject {
    internal let wrapped: SentryInternalDebugApi

    internal init(_ wrapped: SentryInternalDebugApi) {
        self.wrapped = wrapped
    }

    @objc public var images: [SentryObjCDebugMeta] {
        wrapped.images.map { SentryObjCDebugMeta($0) }
    }

    @objc public func imagesForAddresses(_ addresses: [NSNumber]) -> [SentryObjCDebugMeta] {
        let uint64Addresses = addresses.map { $0.uint64Value }
        return wrapped.images(forAddresses: uint64Addresses).map { SentryObjCDebugMeta($0) }
    }
}
// swiftlint:enable missing_docs
