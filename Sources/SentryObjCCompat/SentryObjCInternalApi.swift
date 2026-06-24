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

    @objc public var swizzle: SentryObjCInternalSwizzleApi {
        SentryObjCInternalSwizzleApi(wrapped.value.swizzle)
    }

    @objc public var appStart: SentryObjCInternalAppStartApi {
        SentryObjCInternalAppStartApi(wrapped.value.appStart)
    }

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS) || os(visionOS))
    @objc public var performance: SentryObjCInternalPerformanceApi {
        SentryObjCInternalPerformanceApi(wrapped.value.performance)
    }
#endif

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS))
    @objc public var screenshot: SentryObjCInternalScreenshotApi {
        SentryObjCInternalScreenshotApi(wrapped.value.screenshot)
    }

    @objc public var viewHierarchy: SentryObjCInternalViewHierarchyApi {
        SentryObjCInternalViewHierarchyApi(wrapped.value.viewHierarchy)
    }

    @objc public var screen: SentryObjCInternalScreenApi {
        SentryObjCInternalScreenApi(wrapped.value.screen)
    }

    @objc public var replay: SentryObjCInternalReplayApi {
        SentryObjCInternalReplayApi(wrapped.value.replay)
    }
#endif

#if !(os(watchOS) || os(tvOS) || os(visionOS))
    @objc public var profiling: SentryObjCInternalProfilingApi {
        SentryObjCInternalProfilingApi(wrapped.value.profiling)
    }
#endif

    @objc public func setTrace(_ traceId: SentryObjCId, spanId: SentryObjCSpanId) {
        wrapped.value.setTrace(traceId.wrapped, spanId: spanId.wrapped)
    }

    @objc public func setLogOutput(_ output: ((String) -> Void)?) {
        wrapped.value.setLogOutput(output)
    }

    @objc public func ignoreNextSignal(_ signum: Int32) {
        wrapped.value.ignoreNextSignal(signum)
    }

    @objc public var options: SentryObjCOptions {
        SentryObjCOptions(wrapped.value.options)
    }

    @objc public func options(fromDictionary dictionary: [String: Any]) throws -> SentryObjCOptions {
        SentryObjCOptions(try wrapped.value.options(fromDictionary: dictionary))
    }
}
// swiftlint:enable missing_docs
