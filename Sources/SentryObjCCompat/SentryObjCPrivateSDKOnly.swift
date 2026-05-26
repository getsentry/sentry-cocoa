// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif

public final class SentryObjCPrivateSDKOnly: NSObject {

    @objc public static func storeEnvelope(_ envelope: SentryObjCEnvelope) {
        PrivateSentrySDKOnly.store(envelope.wrapped)
    }

    @objc public static func captureEnvelope(_ envelope: SentryObjCEnvelope) {
        PrivateSentrySDKOnly.capture(envelope.wrapped)
    }

    @objc public static func envelopeWithData(_ data: Data) -> SentryObjCEnvelope? {
        guard let envelope = PrivateSentrySDKOnly.envelope(with: data) else { return nil }
        return SentryObjCEnvelope(envelope)
    }

    @objc public static func setSdkName(_ sdkName: String, andVersionString versionString: String) {
        PrivateSentrySDKOnly.setSdkName(sdkName, andVersionString: versionString)
    }

    @objc public static func setSdkName(_ sdkName: String) {
        PrivateSentrySDKOnly.setSdkName(sdkName)
    }

    @objc public static func getSdkName() -> String {
        PrivateSentrySDKOnly.getSdkName()
    }

    @objc public static func getSdkVersionString() -> String {
        PrivateSentrySDKOnly.getSdkVersionString()
    }

    @objc public static func addSdkPackage(_ name: String, version: String) {
        PrivateSentrySDKOnly.addSdkPackage(name, version: version)
    }

    @objc public static func getExtraContext() -> [String: Any] {
        PrivateSentrySDKOnly.getExtraContext()
    }

    @objc public static func setTrace(_ traceId: SentryObjCId, spanId: SentryObjCSpanId) {
        PrivateSentrySDKOnly.setTrace(traceId.wrapped, spanId: spanId.wrapped)
    }

    @objc public static var installationID: String {
        PrivateSentrySDKOnly.installationID
    }

    @objc public static var appStartMeasurementHybridSDKMode: Bool {
        get { PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode }
        set { PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = newValue }
    }

    @objc public static func userWithDictionary(_ dictionary: [String: Any]) -> SentryObjCUser {
        SentryObjCUser(PrivateSentrySDKOnly.user(with: dictionary))
    }

    @objc public static func breadcrumbWithDictionary(_ dictionary: [String: Any]) -> SentryObjCBreadcrumb {
        SentryObjCBreadcrumb(PrivateSentrySDKOnly.breadcrumb(with: dictionary))
    }

    @objc public static func setLogOutput(_ output: @escaping (String) -> Void) {
        PrivateSentrySDKOnly.setLogOutput(output)
    }

    @objc public static func ignoreNextSignal(_ signum: Int32) {
        PrivateSentrySDKOnly.ignoreNextSignal(signum)
    }
}

// swiftlint:enable missing_docs
