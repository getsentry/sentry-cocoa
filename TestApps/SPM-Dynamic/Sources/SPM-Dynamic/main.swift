@_spi(Private) import Sentry
import Foundation
import ObjCConsumer

// Exercise either producer's binary without starting integrations or sending network requests.
precondition(SentryId().sentryIdString.count == 32)
precondition(SentrySDKLog.willLog(atLevel: .fatal))
precondition(sentryObjCConsumer())
// Inspect the bundle containing the loaded SDK code, not an unused framework copy.
let framework = Bundle(for: SentrySDKLog.self)
guard framework.bundleURL.lastPathComponent == "Sentry.framework" else {
    fatalError("Sentry must be dynamically loaded from Sentry.framework")
}
guard let privacyManifest = framework.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") else {
    fatalError("The packaged framework is missing its privacy manifest")
}
let manifest = try Data(contentsOf: privacyManifest)
_ = try PropertyListSerialization.propertyList(from: manifest, format: nil)
print("Dynamic SDK: public API, SPI, Objective-C and loaded framework resources passed")
