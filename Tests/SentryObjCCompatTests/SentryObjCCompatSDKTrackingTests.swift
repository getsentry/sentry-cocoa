import Foundation

#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif

@testable import SentryObjCCompat
import XCTest

final class SentryObjCCompatSDKTrackingTests: XCTestCase {

    override func tearDown() {
        SentryObjCSDK.close()
        super.tearDown()
    }

    func testEnvelopeHeaderAfterObjCStart_usesObjCSdkName() throws {
        SentryObjCSDK.start { options in
            options.dsn = "https://key@sentry.io/123"
            options.enableCrashHandler = false
        }

        let envelope = SentryEnvelope(id: SentryId(), items: [])
        let data = try XCTUnwrap(SentrySerializationSwift.data(with: envelope))
        let headerLine = try XCTUnwrap(
            String(data: data, encoding: .utf8)?
                .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
                .first
        )
        let header = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(headerLine.utf8)) as? [String: Any]
        )
        let sdk = try XCTUnwrap(header["sdk"] as? [String: Any])

        XCTAssertEqual(sdk["name"] as? String, "sentry.cocoa.objc")
    }
}
