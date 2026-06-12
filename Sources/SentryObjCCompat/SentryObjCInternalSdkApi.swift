// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalSdkApi) public final class SentryObjCInternalSdkApi: NSObject {
    internal let wrapped: SentryInternalSdkApi

    internal init(_ wrapped: SentryInternalSdkApi) {
        self.wrapped = wrapped
    }

    @objc public var name: String {
        get { wrapped.name }
        set { wrapped.name = newValue }
    }

    @objc public var versionString: String {
        get { wrapped.versionString }
        set { wrapped.versionString = newValue }
    }

    @objc public func setName(_ name: String, version: String) {
        wrapped.setName(name, version: version)
    }

    @objc public func addPackageName(_ name: String, version: String) {
        wrapped.addPackage(name: name, version: version)
    }

    @objc public var extraContext: [String: Any] {
        wrapped.extraContext
    }

    @objc public var installationID: String {
        wrapped.installationID
    }
}
// swiftlint:enable missing_docs
