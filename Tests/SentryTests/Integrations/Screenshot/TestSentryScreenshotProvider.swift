#if os(iOS) || os(tvOS) || os(visionOS)

#if canImport(UIKit)
import UIKit
#endif
#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

class TestSentryScreenshotSource: SentryScreenshotSource {

    var result: [Data] = []
    var images: [UIImage] = []
    var processScreenshotsCallback: (() -> Void)?

    override func appScreenshotsData() -> [Data] {
        processScreenshotsCallback?()
        return result
    }
 
    override func appScreenshotsFromMainThread() -> [UIImage] {
        return images
    }
}

#endif // os(iOS) || os(tvOS) || os(visionOS)
