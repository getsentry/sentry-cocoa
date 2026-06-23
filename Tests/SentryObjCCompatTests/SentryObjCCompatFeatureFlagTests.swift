import Foundation

#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

@testable import SentryObjCCompat
import XCTest

final class SentryObjCCompatFeatureFlagTests: XCTestCase {

    override func setUp() {
        super.setUp()
        SentryObjCSDK.start { options in
            options.dsn = "https://key@sentry.io/123"
            options.enableCrashHandler = false
            options.tracesSampleRate = 1.0
        }
    }

    override func tearDown() {
        SentryObjCSDK.close()
        super.tearDown()
    }

    func testSpanAddFeatureFlagWithName_shouldSerializeOnSpanData() throws {
        // -- Arrange --
        let sut = SentryObjCSDK.startTransaction(name: "transaction", operation: "op")

        // -- Act --
        sut.addFeatureFlag(name: "checkout", result: true)

        // -- Assert --
        let serialized = sut.wrapped.serialize()
        let data = try XCTUnwrap(serialized["data"] as? [String: Any])
        XCTAssertEqual(try XCTUnwrap(data["flag.evaluation.checkout"] as? Bool), true)
    }

    func testSpanRemoveFeatureFlagWithName_shouldRemoveFromSpanData() throws {
        // -- Arrange --
        let sut = SentryObjCSDK.startTransaction(name: "transaction", operation: "op")
        sut.addFeatureFlag(name: "checkout", result: true)

        // -- Act --
        sut.removeFeatureFlag(name: "checkout")

        // -- Assert --
        let serialized = sut.wrapped.serialize()
        let data = try XCTUnwrap(serialized["data"] as? [String: Any])
        XCTAssertNil(data["flag.evaluation.checkout"])
    }
}
