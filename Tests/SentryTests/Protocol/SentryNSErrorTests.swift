#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

class SentryNSErrorTests: XCTestCase {

    func testSerialize() {
        let error = SentryNSError(domain: "domain", code: 10)

        let actual = error.serialize()
        
        XCTAssertEqual(error.domain, actual["domain"] as? String)
        XCTAssertEqual(error.code, actual["code"] as? Int)
    }
    
    func testDecode_WithAllProperties() throws {
        // Arrange
        let error = SentryNSError(domain: "domain", code: 10)
        let data = try XCTUnwrap(SentrySerializationSwift.data(withJSONObject: error.serialize()))
        
        // Act
        let decoded = try XCTUnwrap(decodeFromJSONData(jsonData: data) as SentryNSErrorDecodable?)
        
        // Assert
        XCTAssertEqual(error.code, decoded.code)
        XCTAssertEqual(error.domain, decoded.domain)
    }
    
    func testDecode_WithRemovedDomain_ReturnsNil() throws {
        // Arrange
        let error = SentryNSError(domain: "domain", code: 10)
        var serialized = error.serialize()
        serialized.removeValue(forKey: "domain")
        let data = try XCTUnwrap(SentrySerializationSwift.data(withJSONObject: serialized))
        
        // Act & Assert
        XCTAssertNil(decodeFromJSONData(jsonData: data) as SentryNSErrorDecodable?)
    }

    func testSerializeWithUnderlyingNSError() {
        let inputUnderlyingErrorCode = 5_123
        let inputUnderlyingError = NSError(domain: "test-error-domain", code: inputUnderlyingErrorCode)
        let inputDescription = "some test error"
        let actualError = SentryError.unknownError.nsError(
            description: inputDescription, underlyingError: inputUnderlyingError)

        XCTAssertEqual(actualError.localizedDescription, inputDescription)
        
        guard let actualUnderlyingError = actualError.userInfo[NSUnderlyingErrorKey] as? NSError else {
            XCTFail("Expected an underlying error in the returned error's info dict")
            return
        }
        XCTAssertEqual(actualUnderlyingError.code, inputUnderlyingErrorCode)
        XCTAssertEqual(actualUnderlyingError.domain, inputUnderlyingError.domain)
    }

    func testSerializeWithUnderlyingNSException() {
        let inputExceptionName = NSExceptionName.decimalNumberDivideByZeroException
        let inputExceptionReason = "test exception reason"
        let inputUnderlyingException = NSException(name: inputExceptionName, reason: inputExceptionReason, userInfo: ["some userinfo key": "some userinfo value"])
        let inputDescription = "some test exception"

        let actualError = SentryError.unknownError.nsError(
            description: inputDescription, exception: inputUnderlyingException)

        XCTAssertEqual(actualError.localizedDescription, "\(inputDescription) (\(inputExceptionReason))")
    }

    func testWithKernelError() {
        let inputKernelErrorCode = KERN_NOT_RECEIVER
        let inputDescription = "some test kernel error"
        let actualError = SentryError.unknownError.nsError(
            description: inputDescription, kernelErrorCode: Int32(inputKernelErrorCode))

        XCTAssertEqual(
            actualError.localizedDescription,
            "\(inputDescription) (The task in question does not hold receive rights for the port argument.)")
    }
}
