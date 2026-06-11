// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalApi) public final class SentryObjCInternalApi: NSObject {
    internal let wrapped = SentrySDK.`internal`

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
    #endif

    @objc public var appStart: SentryObjCInternalAppStartApi {
        SentryObjCInternalAppStartApi(wrapped.appStart)
    }

    @objc public var envelope: SentryObjCInternalEnvelopeApi {
        SentryObjCInternalEnvelopeApi(wrapped.envelope)
    }

    @objc public var swizzle: SentryObjCInternalSwizzleApi {
        SentryObjCInternalSwizzleApi(wrapped.swizzle)
    }

    @objc public func userWithDictionary(_ dictionary: [String: Any]) -> SentryObjCUser {
        SentryObjCUser(wrapped.userWithDictionary(dictionary))
    }

    @objc public func breadcrumbWithDictionary(_ dictionary: [String: Any]) -> SentryObjCBreadcrumb {
        SentryObjCBreadcrumb(wrapped.breadcrumbWithDictionary(dictionary))
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

    @objc public func setSdkName(_ name: String, version: String) {
        wrapped.setSdkName(name, version: version)
    }

    @objc(setSdkName:)
    public func setSdkNameOnly(_ name: String) {
        wrapped.setSdkName(name)
    }

    @objc public var sdkName: String {
        wrapped.sdkName
    }

    @objc public var sdkVersionString: String {
        wrapped.sdkVersionString
    }

    @objc public func addSdkPackageName(_ name: String, version: String) {
        wrapped.addSdkPackage(name: name, version: version)
    }

    @objc public var extraContext: [String: Any] {
        wrapped.extraContext
    }

    @objc public var installationID: String {
        wrapped.installationID
    }

    @objc public var options: SentryObjCOptions {
        SentryObjCOptions(wrapped.options)
    }

    @objc public func optionsFromDictionary(_ dictionary: [String: Any]) throws -> SentryObjCOptions {
        let options = try wrapped.options(fromDictionary: dictionary)
        return SentryObjCOptions(options)
    }

    @objc public var debugImages: [SentryObjCDebugMeta] {
        wrapped.debugImages.map { SentryObjCDebugMeta($0) }
    }

    @objc public func debugImagesForAddresses(_ addresses: [NSNumber]) -> [SentryObjCDebugMeta] {
        let uint64Addresses = addresses.map { $0.uint64Value }
        return wrapped.debugImages(forAddresses: uint64Addresses).map { SentryObjCDebugMeta($0) }
    }
}
// swiftlint:enable missing_docs
