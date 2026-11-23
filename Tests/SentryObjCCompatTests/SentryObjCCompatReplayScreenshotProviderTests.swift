import Foundation

#if canImport(UIKit) && !SENTRY_NO_UI_FRAMEWORK && (os(iOS) || os(tvOS) || os(visionOS))

#if SWIFT_PACKAGE && !SDK_V10
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

@testable import SentryObjCCompat
import UIKit
import XCTest

final class SentryObjCCompatReplayScreenshotProviderTests: XCTestCase {

    private final class TestScreenshotProvider: NSObject, SentryObjCReplayScreenshotProvider {
        let image = UIImage()
        private(set) var invocations: [UIView] = []

        func image(view: UIView, onComplete: @escaping (UIImage) -> Void) {
            invocations.append(view)
            onComplete(image)
        }
    }

    func testTimedImage_shouldForwardProviderImageWithZeroDurations() throws {
        // -- Arrange --
        let provider = TestScreenshotProvider()
        let sut = SentryObjCReplayScreenshotProviderAdapter(provider)
        let view = UIView()
        var receivedImage: UIImage?
        var receivedMetadata: SentryViewPhotographerScreenshotMetadata?

        // -- Act --
        sut.timedImage(view: view) { image, metadata in
            receivedImage = image
            receivedMetadata = metadata
        }

        // -- Assert --
        XCTAssertEqual(provider.invocations.count, 1)
        XCTAssertIdentical(provider.invocations.first, view)
        XCTAssertIdentical(receivedImage, provider.image)
        let metadata = try XCTUnwrap(receivedMetadata)
        XCTAssertEqual(metadata.redactDuration, 0)
        XCTAssertEqual(metadata.renderDuration, 0)
        XCTAssertEqual(metadata.maskDuration, 0)
        XCTAssertEqual(metadata.mainThreadDuration, 0)
    }

    func testImage_shouldForwardProviderImage() {
        // -- Arrange --
        let provider = TestScreenshotProvider()
        let sut = SentryObjCReplayScreenshotProviderAdapter(provider)
        let view = UIView()
        var receivedImage: UIImage?

        // -- Act --
        sut.image(view: view) { image in
            receivedImage = image
        }

        // -- Assert --
        XCTAssertEqual(provider.invocations.count, 1)
        XCTAssertIdentical(provider.invocations.first, view)
        XCTAssertIdentical(receivedImage, provider.image)
    }
}

#endif
