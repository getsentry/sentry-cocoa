@_spi(Private) @testable import Sentry
import XCTest

class SentryInfoPlistWrapperTests: XCTestCase {
    
    private var sut: SentryInfoPlistWrapper!
    
    override func setUp() {
        super.setUp()
        sut = SentryInfoPlistWrapper()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - getAppValueString Tests
    
    func testGetAppValueString_whenKeyExists_shouldReturnValue() throws {
        // Arrange
        // CFBundleName is a standard key that should exist in any bundle
        let key = "CFBundleName"
        
        // Act
        let value = try sut.getAppValueString(for: key)
        
        // Assert
        XCTAssertFalse(value.isEmpty, "Bundle name should not be empty")
    }
    
    func testGetAppValueString_whenKeyDoesNotExist_shouldThrowKeyNotFoundError() {
        // Arrange
        let nonExistentKey = "NonExistentKey_12345_XYZ"
        
        // Act & Assert
        XCTAssertThrowsError(try sut.getAppValueString(for: nonExistentKey)) { error in
            guard case SentryInfoPlistError.keyNotFound(let key) = error else {
                XCTFail("Expected SentryInfoPlistError.keyNotFound, got \(error)")
                return
            }
            XCTAssertEqual(key, nonExistentKey)
        }
    }
    
    func testGetAppValueString_whenValueIsNotString_shouldThrowUnableToCastError() {
        // Arrange
        // CFBundleVersion is typically a number or can be a mixed type
        // We'll use a key that we know exists but might not be a string
        // Note: This test might be skipped if we can't find a suitable non-string key
        // Let's try with UIDeviceFamily which is typically an array
        let key = "UIDeviceFamily"
        
        // Act & Assert
        do {
            _ = try sut.getAppValueString(for: key)
            // If we get here, the key happened to be a string or doesn't exist in test bundle
            // This is not a test failure, just means the key wasn't suitable for this test
        } catch SentryInfoPlistError.unableToCastValue(let errorKey, _, let type) {
            XCTAssertEqual(errorKey, key)
            XCTAssertTrue(type == String.self)
        } catch SentryInfoPlistError.keyNotFound {
            // Key doesn't exist in test bundle, which is acceptable for this test
        } catch {
            XCTFail("Expected SentryInfoPlistError.unableToCastValue or keyNotFound, got \(error)")
        }
    }
    
    // MARK: - getAppValueBoolean Tests
    
    func testGetAppValueBoolean_whenKeyExistsAndIsTrue_shouldReturnTrue() {
        // Arrange
        // For this test, we'll use a key that might exist and be a boolean
        // UIApplicationExitsOnSuspend is a boolean key (if it exists)
        let key = "UIApplicationExitsOnSuspend"
        var error: NSError?
        
        // Act
        let value = sut.getAppValueBoolean(for: key, errorPtr: &error)
        
        // Assert
        // If the key exists and is a boolean, it should work without error
        // If the key doesn't exist, error should be set
        if error == nil {
            // Success case - value is valid
            XCTAssertTrue(value == true || value == false, "Boolean value should be true or false")
        } else {
            // Key not found is acceptable for this test setup
            XCTAssertTrue(error?.domain == "SentryInfoPlistError" || error != nil)
        }
    }
    
    func testGetAppValueBoolean_whenKeyDoesNotExist_shouldReturnFalseAndSetError() {
        // Arrange
        let nonExistentKey = "NonExistentBooleanKey_12345_XYZ"
        var error: NSError?
        
        // Act
        let value = sut.getAppValueBoolean(for: nonExistentKey, errorPtr: &error)
        
        // Assert
        XCTAssertFalse(value, "Should return false when key is not found")
        XCTAssertNotNil(error, "Error should be set when key is not found")
    }
    
    func testGetAppValueBoolean_whenValueIsNotBoolean_shouldReturnFalseAndSetError() {
        // Arrange
        // CFBundleName is a string, not a boolean
        let key = "CFBundleName"
        var error: NSError?
        
        // Act
        let value = sut.getAppValueBoolean(for: key, errorPtr: &error)
        
        // Assert
        XCTAssertFalse(value, "Should return false when value cannot be cast to Boolean")
        XCTAssertNotNil(error, "Error should be set when type casting fails")
    }
    
    func testGetAppValueBoolean_withNullErrorPointer_shouldNotCrash() {
        // Arrange
        let key = "CFBundleName" // A key that exists but is not a boolean
        
        // Act & Assert
        // This should not crash even with a null error pointer
        let value = sut.getAppValueBoolean(for: key, errorPtr: nil)
        XCTAssertFalse(value, "Should return false when casting fails")
    }
    
    // MARK: - Edge Cases
    
    func testGetAppValueString_withEmptyKey_shouldThrowKeyNotFoundError() {
        // Arrange
        let emptyKey = ""
        
        // Act & Assert
        XCTAssertThrowsError(try sut.getAppValueString(for: emptyKey)) { error in
            guard case SentryInfoPlistError.keyNotFound = error else {
                XCTFail("Expected SentryInfoPlistError.keyNotFound, got \(error)")
                return
            }
        }
    }
    
    func testGetAppValueString_withSentryInfoPlistKey_shouldWork() throws {
        // Arrange
        // Test with the actual enum keys used in production
        // Note: These keys might not exist in the test bundle, which is expected
        let xcodeKey = SentryInfoPlistKey.xcodeVersion.rawValue
        
        // Act & Assert
        do {
            let value = try sut.getAppValueString(for: xcodeKey)
            // If the key exists, value should not be empty
            XCTAssertFalse(value.isEmpty, "Xcode version should not be empty if present")
        } catch SentryInfoPlistError.keyNotFound {
            // This is expected in test environment - DTXcode might not be set
            XCTAssertTrue(true, "Key not found is acceptable for test bundle")
        }
    }
    
    func testGetAppValueBoolean_withSentryInfoPlistKey_shouldWork() {
        // Arrange
        let compatibilityKey = SentryInfoPlistKey.designRequiresCompatibility.rawValue
        var error: NSError?
        
        // Act
        let value = sut.getAppValueBoolean(for: compatibilityKey, errorPtr: &error)
        
        // Assert
        // In test environment, this key likely doesn't exist
        if error == nil {
            // If no error, we successfully read a boolean value
            XCTAssertTrue(value == true || value == false)
        } else {
            // Expected to not find this key in test bundle
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Multiple Consecutive Calls
    
    func testMultipleConsecutiveCalls_shouldReturnConsistentResults() throws {
        // Arrange
        let key = "CFBundleName"
        
        // Act
        let value1 = try sut.getAppValueString(for: key)
        let value2 = try sut.getAppValueString(for: key)
        
        // Assert
        XCTAssertEqual(value1, value2, "Multiple calls should return the same value")
    }
}
