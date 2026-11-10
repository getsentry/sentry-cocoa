@_spi(Private) import Sentry
import Foundation
import ObjCConsumer

// Exercise either producer's binary without starting integrations or sending network requests.
precondition(SentryId().sentryIdString.count == 32)
precondition(SentrySDKLog.willLog(atLevel: .fatal))
precondition(sentryObjCConsumer())
// SwiftPM copies the binary framework beside the executable. Inspect that bundle directly;
// Bundle(for:) resolves to the executable if SwiftPM selects a statically linked variant.
let frameworkURL = Bundle.main.bundleURL.appendingPathComponent("Sentry.framework")
guard let framework = Bundle(url: frameworkURL),
      let privacyManifest = framework.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") else {
    fatalError("The packaged framework is missing its privacy manifest")
}
let manifest = try Data(contentsOf: privacyManifest)
_ = try PropertyListSerialization.propertyList(from: manifest, format: nil)
print("Binary SDK: public API, SPI, Objective-C and resources passed")
