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

    @objc public var envelope: SentryObjCInternalEnvelopeApi {
        SentryObjCInternalEnvelopeApi(wrapped.value.envelope)
    }

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
    @objc public var performance: SentryObjCInternalPerformanceApi {
        SentryObjCInternalPerformanceApi(wrapped.value.performance)
    }

    @objc public var screenshot: SentryObjCInternalScreenshotApi {
        SentryObjCInternalScreenshotApi(wrapped.value.screenshot)
    }

    @objc public var viewHierarchy: SentryObjCInternalViewHierarchyApi {
        SentryObjCInternalViewHierarchyApi(wrapped.value.viewHierarchy)
    }

    @objc public var screen: SentryObjCInternalScreenApi {
        SentryObjCInternalScreenApi(wrapped.value.screen)
    }
#endif
}
// swiftlint:enable missing_docs
