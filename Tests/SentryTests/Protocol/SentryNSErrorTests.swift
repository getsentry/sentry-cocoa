import SentryTestUtils
import XCTest

class SentryNSErrorTests: XCTestCase {

    func testSerialize() {
        let error = SentryNSError(domain: "domain", code: 10)

        let actual = error.serialize()
        
        XCTAssertEqual(error.domain, actual["domain"] as? String)
        XCTAssertEqual(error.code, actual["code"] as? Int)
    }

    func testSerializeWithUnderlyingNSError() {
        let inputUnderlyingErrorCode = 5_123
        let inputUnderlyingError = NSError(domain: "test-error-domain", code: inputUnderlyingErrorCode)
        let inputDescription = "some test error"
        let actualError = NSErrorFromSentryErrorWithUnderlyingError(SentryError.unknownError, inputDescription, inputUnderlyingError)

        XCTAssertEqual(actualError?.localizedDescription, inputDescription)
        
        guard let error = actualError, let actualUnderlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? NSError else {
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

        let actualError = NSErrorFromSentryErrorWithException(SentryError.unknownError, inputDescription, inputUnderlyingException)

        guard let actualDescription = actualError?.localizedDescription else {
            XCTFail("Expected a localizedDescription in the resulting error")
            return
        }
        XCTAssertEqual(actualDescription, "\(inputDescription) (\(inputExceptionReason))")
    }

    func testWithKernelError() {
        let inputKernelErrorCode = KERN_NOT_RECEIVER
        let inputDescription = "some test kernel error"
        let actualError = NSErrorFromSentryErrorWithKernelError(SentryError.unknownError, inputDescription, inputKernelErrorCode)

        guard let actualDescription = actualError?.localizedDescription else {
            XCTFail("Expected a localizedDescription in the resulting error")
            return
        }
        XCTAssertEqual(actualDescription, "\(inputDescription) (The task in question does not hold receive rights for the port argument.)")
    }
}
