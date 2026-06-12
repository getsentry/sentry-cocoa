// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
@_spi(Private) internal import SentrySwift
#else
@_spi(Private) internal import Sentry
#endif
import Foundation

@available(*, deprecated, message: "Use SentryObjCSDK.internal instead")
@objc(SentryObjCPrivateSDKOnly) public final class SentryObjCPrivateSDKOnly: NSObject {

    // swiftlint:disable:next todo
    // TODO: Replace selector dispatch with direct calls once PrivateSentrySDKOnly is migrated to Swift.
    // SentryEnvelope is forward-declared in ObjC headers but defined in Swift, making ObjC methods
    // that use it unavailable through the Swift importer. Selector dispatch is a workaround.

    @objc public static func storeEnvelope(_ envelope: SentryObjCEnvelope) {
        let cls = PrivateSentrySDKOnly.self as AnyObject
        _ = cls.perform(NSSelectorFromString("storeEnvelope:"), with: envelope.wrapped)
    }

    @objc public static func captureEnvelope(_ envelope: SentryObjCEnvelope) {
        let cls = PrivateSentrySDKOnly.self as AnyObject
        _ = cls.perform(NSSelectorFromString("captureEnvelope:"), with: envelope.wrapped)
    }

    @objc public static func envelopeWithData(_ data: Data) -> SentryObjCEnvelope? {
        guard let envelope = SentrySerializationSwift.envelope(with: data) else { return nil }
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
        PrivateSentrySDKOnly.getExtraContext() as? [String: Any] ?? [:]
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
