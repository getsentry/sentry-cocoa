import Foundation
// Both modes use SwiftPM; this flag selects the SwiftPM-built XCFramework.
#if SENTRY_SPM_FRAMEWORK
#if SDK_V10
@_spi(Private) import Sentry
#else
@_spi(Private) import SentrySwift
#endif
import ObjCConsumer

// Exercise the packaged SDK without starting integrations or sending network requests.
precondition(SentryId().sentryIdString.count == 32)
precondition(SentrySDKLog.willLog(atLevel: .fatal))
precondition(sentryObjCConsumer())
let framework = Bundle(for: SentrySDKLog.self)
guard let privacyManifest = framework.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") else {
    fatalError("The packaged framework is missing its privacy manifest")
}
let manifest = try Data(contentsOf: privacyManifest)
_ = try PropertyListSerialization.propertyList(from: manifest, format: nil)
print("SPM-built SDK: public API, SPI, Objective-C and resources passed")
#else
import Sentry

SentrySDK.start { options in
    options.dsn = "https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557"
    options.debug = true
}

/**
 Some func to build a stacktrace.
 */
private func captureMessage() {
    let eventId = SentrySDK.capture(message: "Yeah captured a message")

    // Some Delay to wait for sending the message
    let group = DispatchGroup()
    group.enter()
    let queue = DispatchQueue(label: "delay", qos: .background, attributes: [])
    queue.asyncAfter(deadline: .now() + 2) {
        group.leave()
    }
    group.wait()
    
    print("\(String(describing: eventId))")
}

captureMessage()
#endif
