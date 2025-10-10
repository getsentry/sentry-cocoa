import CwlPreconditionTesting
@_spi(Private) @testable import Sentry
@_spi(Private) @testable import SentryTestUtils
import XCTest

class TestInfoPlistWrapperTests: XCTestCase {

    // MARK: - getAppValueString(for:)

    func testGetAppValueString_withoutMockedValue_shouldFailWithPreconditionFailure() throws {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        // Don't mock any value for this key

        // -- Act --
        let e = catchBadInstruction {
            do {
                _ = try sut.getAppValueString(for: "unmockedKey")
            } catch {
                // noop
            }
        }

        // -- Assert --
        XCTAssertNotNil(e)
    }

    func testGetAppValueString_withMockedValue_withSingleInvocations_shouldReturnMockedValue() throws {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        sut.mockGetAppValueStringReturnValue(forKey: "key", value: "value")

        // -- Act --
        let result = try sut.getAppValueString(for: "key")

        // -- Assert --
        XCTAssertEqual(result, "value")
    }

    func testGetAppValueString_withMockedValue_withMultipleInvocations_shouldReturnSameValue() throws {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        sut.mockGetAppValueStringReturnValue(forKey: "key1", value: "value1")

        // -- Act --
        let result1 = try sut.getAppValueString(for: "key1")
        let result2 = try sut.getAppValueString(for: "key1")

        // -- Assert --
        XCTAssertEqual(result1, "value1")
        XCTAssertEqual(result2, "value1")
    }
    
    func testGetAppValueString_shouldRecordInvocations() throws {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        sut.mockGetAppValueStringReturnValue(forKey: "key1", value: "value1")
        sut.mockGetAppValueStringReturnValue(forKey: "key2", value: "value2")
        sut.mockGetAppValueStringReturnValue(forKey: "key3", value: "value3")

        // -- Act --
        _ = try sut.getAppValueString(for: "key1")
        _ = try sut.getAppValueString(for: "key2")
        _ = try sut.getAppValueString(for: "key3")

        // -- Assert --
        XCTAssertEqual(sut.getAppValueStringInvocations.count, 3)
        XCTAssertEqual(sut.getAppValueStringInvocations.invocations.element(at: 0), "key1")
        XCTAssertEqual(sut.getAppValueStringInvocations.invocations.element(at: 1), "key2")
        XCTAssertEqual(sut.getAppValueStringInvocations.invocations.element(at: 2), "key3")
    }
    
    func testGetAppValueString_withDifferentKeys_shouldReturnDifferentValues() throws {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        sut.mockGetAppValueStringReturnValue(forKey: "key1", value: "value1")
        sut.mockGetAppValueStringReturnValue(forKey: "key2", value: "value2")

        // -- Act --
        let result1 = try sut.getAppValueString(for: "key1")
        let result2 = try sut.getAppValueString(for: "key2")

        // -- Assert --
        XCTAssertEqual(result1, "value1")
        XCTAssertEqual(result2, "value2")
        XCTAssertEqual(sut.getAppValueStringInvocations.count, 2)
    }
    
    func testGetAppValueString_withFailureResult_shouldThrowError() {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        sut.mockGetAppValueStringThrowError(forKey: "key", error: SentryInfoPlistError.keyNotFound(key: "testKey"))

        // -- Act & Assert --
        XCTAssertThrowsError(try sut.getAppValueString(for: "key")) { error in
            guard case SentryInfoPlistError.keyNotFound(let key) = error else {
                XCTFail("Expected SentryInfoPlistError.keyNotFound, got \(error)")
                return
            }
            XCTAssertEqual(key, "testKey")
        }
    }
    
    func testGetAppValueString_withDifferentErrorTypes_shouldThrowCorrectError() {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        
        // Test mainInfoPlistNotFound
        sut.mockGetAppValueStringThrowError(forKey: "key1", error: SentryInfoPlistError.mainInfoPlistNotFound)
        XCTAssertThrowsError(try sut.getAppValueString(for: "key1")) { error in
            guard case SentryInfoPlistError.mainInfoPlistNotFound = error else {
                XCTFail("Expected SentryInfoPlistError.mainInfoPlistNotFound, got \(error)")
                return
            }
        }
        
        // Test unableToCastValue
        sut.mockGetAppValueStringThrowError(forKey: "key2", error: SentryInfoPlistError.unableToCastValue(key: "castKey", value: 123, type: String.self))
        XCTAssertThrowsError(try sut.getAppValueString(for: "key2")) { error in
            guard case SentryInfoPlistError.unableToCastValue(let key, let value, let type) = error else {
                XCTFail("Expected SentryInfoPlistError.unableToCastValue, got \(error)")
                return
            }
            XCTAssertEqual(key, "castKey")
            XCTAssertEqual(value as? Int, 123)
            XCTAssertTrue(type == String.self)
        }
    }
    
    func testGetAppValueString_afterThrowingError_shouldRecordInvocation() {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        sut.mockGetAppValueStringThrowError(forKey: "key1", error: SentryInfoPlistError.keyNotFound(key: "testKey"))

        // -- Act --
        _ = try? sut.getAppValueString(for: "key1")

        // -- Assert --
        XCTAssertEqual(sut.getAppValueStringInvocations.count, 1)
        XCTAssertEqual(sut.getAppValueStringInvocations.invocations.element(at: 0), "key1")
    }

    // MARK: - getAppValueBoolean(for:errorPtr:)

    func testGetAppValueBoolean_withoutMockedValue_shouldFailWithPreconditionFailure() throws {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        // Don't mock any value for this key

        // -- Act --
        let e = catchBadInstruction {
            var error: NSError?
            _ = sut.getAppValueBoolean(for: "unmockedKey", errorPtr: &error)
        }

        // -- Assert --
        XCTAssertNotNil(e)
    }

    func testGetAppValueBoolean_withMockedValue_withSingleInvocations_shouldReturnMockedValue() throws {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        sut.mockGetAppValueBooleanReturnValue(forKey: "key", value: true)

        // -- Act --
        var error: NSError?
        let result = sut.getAppValueBoolean(for: "key", errorPtr: &error)

        // -- Assert --
        XCTAssertTrue(result)
        XCTAssertNil(error)
    }

    func testGetAppValueBoolean_withMockedValue_withMultipleInvocations_shouldReturnSameValue() {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        sut.mockGetAppValueBooleanReturnValue(forKey: "key1", value: true)

        // -- Act --
        var error1: NSError?
        let result1 = sut.getAppValueBoolean(for: "key1", errorPtr: &error1)

        var error2: NSError?
        let result2 = sut.getAppValueBoolean(for: "key1", errorPtr: &error2)

        // -- Assert --
        XCTAssertTrue(result1)
        XCTAssertNil(error1)
        XCTAssertTrue(result2)
        XCTAssertNil(error2)
    }
    
    func testGetAppValueBoolean_withFalseValue_shouldReturnFalse() {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        sut.mockGetAppValueBooleanReturnValue(forKey: "key", value: false)

        // -- Act --
        var error: NSError?
        let result = sut.getAppValueBoolean(for: "key", errorPtr: &error)

        // -- Assert --
        XCTAssertFalse(result)
        XCTAssertNil(error)
    }
    
    func testGetAppValueBoolean_withFailureResult_shouldReturnFalseAndSetError() {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        let expectedError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        sut.mockGetAppValueBooleanThrowError(forKey: "key", error: expectedError)

        // -- Act --
        var error: NSError?
        let result = sut.getAppValueBoolean(for: "key", errorPtr: &error)

        // -- Assert --
        XCTAssertFalse(result)
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.domain, "TestDomain")
        XCTAssertEqual(error?.code, 123)
        XCTAssertEqual(error?.localizedDescription, "Test error")
    }
    
    func testGetAppValueBoolean_withFailureResult_withNilErrorPointer_shouldReturnFalse() {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        let expectedError = NSError(domain: "TestDomain", code: 123)
        sut.mockGetAppValueBooleanThrowError(forKey: "key", error: expectedError)

        // -- Act --
        let result = sut.getAppValueBoolean(for: "key", errorPtr: nil)

        // -- Assert --
        XCTAssertFalse(result)
        // No crash should occur when error pointer is nil
    }
    
    func testGetAppValueBoolean_shouldRecordInvocations() {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        sut.mockGetAppValueBooleanReturnValue(forKey: "key1", value: true)
        sut.mockGetAppValueBooleanReturnValue(forKey: "key2", value: false)
        sut.mockGetAppValueBooleanReturnValue(forKey: "key3", value: true)

        // -- Act --
        var error1: NSError?
        _ = sut.getAppValueBoolean(for: "key1", errorPtr: &error1)
        
        var error2: NSError?
        _ = sut.getAppValueBoolean(for: "key2", errorPtr: &error2)
        
        var error3: NSError?
        _ = sut.getAppValueBoolean(for: "key3", errorPtr: &error3)

        // -- Assert --
        XCTAssertEqual(sut.getAppValueBooleanInvocations.count, 3)
        XCTAssertEqual(sut.getAppValueBooleanInvocations.invocations.element(at: 0)?.0, "key1")
        XCTAssertEqual(sut.getAppValueBooleanInvocations.invocations.element(at: 1)?.0, "key2")
        XCTAssertEqual(sut.getAppValueBooleanInvocations.invocations.element(at: 2)?.0, "key3")
    }
    
    func testGetAppValueBoolean_withSuccessResult_withNilErrorPointer_shouldReturnTrue() {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        sut.mockGetAppValueBooleanReturnValue(forKey: "key", value: true)

        // -- Act --
        let result = sut.getAppValueBoolean(for: "key", errorPtr: nil)

        // -- Assert --
        XCTAssertTrue(result)
        // No crash should occur when error pointer is nil
    }
    
    func testGetAppValueBoolean_withDifferentKeys_shouldReturnDifferentValues() {
        // -- Arrange --
        let sut = TestInfoPlistWrapper()
        sut.mockGetAppValueBooleanReturnValue(forKey: "key1", value: true)
        sut.mockGetAppValueBooleanReturnValue(forKey: "key2", value: false)

        // -- Act --
        var error1: NSError?
        let result1 = sut.getAppValueBoolean(for: "key1", errorPtr: &error1)
        
        var error2: NSError?
        let result2 = sut.getAppValueBoolean(for: "key2", errorPtr: &error2)

        // -- Assert --
        XCTAssertTrue(result1)
        XCTAssertNil(error1)
        XCTAssertFalse(result2)
        XCTAssertNil(error2)
    }
}
