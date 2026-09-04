// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

@objc(SentryObjCPrivateSDKOnly) public final class SentryObjCPrivateSDKOnly: NSObject {

    @objc public static func storeEnvelope(_ envelope: SentryObjCEnvelope) {
        SentrySDK.internal.envelope.store(envelope.wrapped)
    }

    @objc public static func captureEnvelope(_ envelope: SentryObjCEnvelope) {
        SentrySDK.internal.envelope.capture(envelope.wrapped)
    }

    @objc public static func envelopeWithData(_ data: Data) -> SentryObjCEnvelope? {
        guard let envelope = SentrySerializationSwift.envelope(with: data) else { return nil }
        return SentryObjCEnvelope(envelope)
    }

    @objc public static func setSdkName(_ sdkName: String, andVersionString versionString: String) {
        SentrySDK.internal.sdk.setName(sdkName, version: versionString)
    }

    @objc public static func setSdkName(_ sdkName: String) {
        SentrySDK.internal.sdk.name = sdkName
    }

    @objc public static func getSdkName() -> String {
        SentrySDK.internal.sdk.name
    }

    @objc public static func getSdkVersionString() -> String {
        SentrySDK.internal.sdk.versionString
    }

    @objc public static func addSdkPackage(_ name: String, version: String) {
        SentrySDK.internal.sdk.addPackage(name: name, version: version)
    }

    @objc public static func getExtraContext() -> [String: Any] {
        SentrySDK.internal.sdk.extraContext
    }

    @objc public static func setTrace(_ traceId: SentryObjCId, spanId: SentryObjCSpanId) {
        SentrySDK.internal.setTrace(traceId.wrapped, spanId: spanId.wrapped)
    }

    @objc public static var installationID: String {
        SentrySDK.internal.sdk.installationID
    }

    @objc public static var appStartMeasurementHybridSDKMode: Bool {
        get { SentrySDK.internal.appStart.hybridSDKMode }
        set { SentrySDK.internal.appStart.hybridSDKMode = newValue }
    }

    @objc public static func userWithDictionary(_ dictionary: [String: Any]) -> SentryObjCUser {
        SentryObjCUser(SentrySDK.internal.user.fromDictionary(dictionary))
    }

    @objc public static func breadcrumbWithDictionary(_ dictionary: [String: Any]) -> SentryObjCBreadcrumb {
        SentryObjCBreadcrumb(SentrySDK.internal.breadcrumbs.fromDictionary(dictionary))
    }

    @objc public static func setLogOutput(_ output: @escaping (String) -> Void) {
        SentrySDK.internal.setLogOutput(output)
    }

    @objc public static func ignoreNextSignal(_ signum: Int32) {
        SentrySDK.internal.ignoreNextSignal(signum)
    }
}

// swiftlint:enable missing_docs
