// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalApi) public final class SentryObjCInternalApi: NSObject {
    internal let wrapped = SentrySDK.internal

    #if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
    @objc public var replay: SentryObjCInternalReplayApi {
        SentryObjCInternalReplayApi(wrapped.replay)
    }

    @objc public var performance: SentryObjCInternalPerformanceApi {
        SentryObjCInternalPerformanceApi(wrapped.performance)
    }

    @objc public var screenshot: SentryObjCInternalScreenshotApi {
        SentryObjCInternalScreenshotApi(wrapped.screenshot)
    }

    @objc public var viewHierarchy: SentryObjCInternalViewHierarchyApi {
        SentryObjCInternalViewHierarchyApi(wrapped.viewHierarchy)
    }

    @objc public var screen: SentryObjCInternalScreenApi {
        SentryObjCInternalScreenApi(wrapped.screen)
    }
    #endif // canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))

    @objc public var appStart: SentryObjCInternalAppStartApi {
        SentryObjCInternalAppStartApi(wrapped.appStart)
    }

    @objc public var envelope: SentryObjCInternalEnvelopeApi {
        SentryObjCInternalEnvelopeApi(wrapped.envelope)
    }

    @objc public var swizzle: SentryObjCInternalSwizzleApi {
        SentryObjCInternalSwizzleApi(wrapped.swizzle)
    }

    @objc public var sdk: SentryObjCInternalSdkApi {
        SentryObjCInternalSdkApi(wrapped.sdk)
    }

    @objc public var debug: SentryObjCInternalDebugApi {
        SentryObjCInternalDebugApi(wrapped.debug)
    }

    @objc public var breadcrumbs: SentryObjCInternalBreadcrumbApi {
        SentryObjCInternalBreadcrumbApi(wrapped.breadcrumbs)
    }

    @objc public var user: SentryObjCInternalUserApi {
        SentryObjCInternalUserApi(wrapped.user)
    }

    @objc public func setTrace(_ traceId: SentryObjCId, spanId: SentryObjCSpanId) {
        wrapped.setTrace(traceId.wrapped, spanId: spanId.wrapped)
    }

    @objc public func setLogOutput(_ output: @escaping (String) -> Void) {
        wrapped.setLogOutput(output)
    }

    @objc public func ignoreNextSignal(_ signum: Int32) {
        wrapped.ignoreNextSignal(signum)
    }

    @objc public var options: SentryObjCOptions {
        SentryObjCOptions(wrapped.options)
    }

    @objc public func optionsFromDictionary(_ dictionary: [String: Any]) throws -> SentryObjCOptions {
        let options = try wrapped.options(fromDictionary: dictionary)
        return SentryObjCOptions(options)
    }
}
// swiftlint:enable missing_docs
