// swiftlint:disable missing_docs
#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif
import Foundation

@objc(SentryObjCInternalSdkApi) public final class SentryObjCInternalSdkApi: NSObject {
    internal let wrapped: Box<SentryInternalSdkApi>

    internal init(_ wrapped: SentryInternalSdkApi) {
        self.wrapped = Box(wrapped)
    }

    @objc public var name: String {
        get { wrapped.value.name }
        set { wrapped.value.name = newValue }
    }

    @objc public var versionString: String {
        get { wrapped.value.versionString }
        set { wrapped.value.versionString = newValue }
    }

    @objc public func setName(_ name: String, version: String) {
        wrapped.value.setName(name, version: version)
    }

    @objc public func addPackageName(_ name: String, version: String) {
        wrapped.value.addPackage(name: name, version: version)
    }

    @objc public var extraContext: [String: Any] {
        wrapped.value.extraContext
    }

    @objc public var installationID: String {
        wrapped.value.installationID
    }
}
// swiftlint:enable missing_docs
