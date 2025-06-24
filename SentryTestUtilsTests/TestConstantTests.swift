import Foundation
@_spi(Private) @testable import SentryTestUtils
import XCTest

class TestConstantTests: XCTestCase {
    func testRealDsn_shouldReturnExpectedValue() {
        XCTAssertEqual(TestConstants.realDSN, "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557")
    }

    func testDsnForTestCase_localTargetClass_shouldUseTypeNameInDSN() {
        // -- Arrange --
        class FooTests: XCTestCase {}

        // -- Act --
        let dsn = TestConstants.dsnForTestCase(type: FooTests.self)

        // -- Assert --
        XCTAssertEqual(dsn, "https://FooTests:unknown@app.getsentry.com/12345")
    }

    func testDsnForTestCase_externalFrameworkObjectiveCClass_shouldUseTypeNameInDSN() {
        // -- Act --
        let dsn = TestConstants.dsnForTestCase(type: NSDecimalNumber.self)

        // -- Assert --
        XCTAssertEqual(dsn, "https://NSDecimalNumber:unknown@app.getsentry.com/12345")
    }

    func testDsnForTestCase_externalFrameworkSwiftClass_shouldUseTypeNameInDSN() {
        // -- Act --
        let dsn = TestConstants.dsnForTestCase(type: String.self)

        // -- Assert --
        XCTAssertEqual(dsn, "https://String:unknown@app.getsentry.com/12345")
    }

    func testDsnForTestCase_whenTestNameIsNil_shouldUseTypeAndFallbackNameInDSN() {
        // -- Act --
        let dsn = TestConstants.dsnForTestCase(type: String.self, testName: nil)

        // -- Assert --
        XCTAssertEqual(dsn, "https://String:unknown@app.getsentry.com/12345")
    }

    func testDsnForTestCase_whenTestNameIsDefined_shouldUseTypeAndTestNameInDSN() {
        // -- Act --
        let dsn = TestConstants.dsnForTestCase(type: String.self, testName: "MyTest")

        // -- Assert --
        XCTAssertEqual(dsn, "https://String:MyTest@app.getsentry.com/12345")
    }

    func testDsnAsString_shouldReturnExpectedValue() {
        // -- Act --
        let dsn = TestConstants.dsnAsString(username: "testUser")
        
        // -- Assert --
        XCTAssertEqual(dsn, "https://testUser:password@app.getsentry.com/12345")
    }
    
    func testDsn_shouldReturnValidDsn() throws {
        // -- Arrange --
        let expectedUrl = try XCTUnwrap(URL(string: "https://testUser:password@app.getsentry.com/12345"))

        // -- Act --
        let dsn = try TestConstants.dsn(username: "testUser")
        
        // -- Assert --
        XCTAssertEqual(dsn.url, expectedUrl)
    }
    
    func testEventWithSerializationError_shouldReturnEventWithEmptyMessage() throws {
        // -- Act --
        let event = TestConstants.eventWithSerializationError

        // -- Assert --
        let message = try XCTUnwrap(event.message)
        XCTAssertEqual(message.formatted, "")
    }

    func testEventWithSerializationError_shouldReturnEventWithEventInSdk() throws {
        // -- Arrange --
        let dateProvider = TestCurrentDateProvider()
        SentryDependencyContainer.sharedInstance().dateProvider = dateProvider

        let date = Date(timeIntervalSince1970: 4_000_000_000)
        dateProvider.setDate(date: date)

        // -- Act --
        let event = TestConstants.eventWithSerializationError

        // -- Assert --
        XCTAssertEqual(event.sdk?.count, 1)
        let sdk = try XCTUnwrap(event.sdk)
        let sdkEvent = try XCTUnwrap(sdk["event"] as? Event)
        XCTAssertEqual(sdkEvent.platform, "cocoa")
        XCTAssertEqual(sdkEvent.timestamp, date)
    }

    func testEnvelope_shouldReturnValidEnvelopeWithOneItem() throws {
        // -- Act --
        let envelope = TestConstants.envelope
        
        // -- Assert --
        XCTAssertNotNil(envelope.header.eventId)
        XCTAssertEqual(envelope.items.count, 1)
    }
}
