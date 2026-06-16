// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalApi) public final class SentryObjCInternalApi: NSObject {
    private let wrapped: Box<SentryInternalApi>

    internal init(_ wrapped: SentryInternalApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public var sdk: SentryObjCInternalSdkApi {
        SentryObjCInternalSdkApi(wrapped.value.sdk)
    }

    @objc public var debug: SentryObjCInternalDebugApi {
        SentryObjCInternalDebugApi(wrapped.value.debug)
    }

    @objc public var breadcrumbs: SentryObjCInternalBreadcrumbApi {
        SentryObjCInternalBreadcrumbApi(wrapped.value.breadcrumbs)
    }

    @objc public var user: SentryObjCInternalUserApi {
        SentryObjCInternalUserApi(wrapped.value.user)
    }
}
// swiftlint:enable missing_docs
