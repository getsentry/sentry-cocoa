@_spi(Private) @testable import Sentry
import XCTest

/// Tests for `SentryInfoPlistWrapper`.
///
/// This test suite uses a custom test bundle (`TestBundle`) with a predefined Info.plist file
/// (`TestInfoPlist.plist`) to ensure consistent and predictable testing. This approach eliminates
/// the need to rely on the environment's Info.plist, which may vary across different test contexts.
///
/// ## Test Setup
///
/// - `TestInfoPlist.plist`: Contains known key-value pairs for testing (strings, booleans, arrays, etc.)
/// - `TestBundle.swift`: Helper class that creates a temporary bundle from the test plist
/// - The bundle is created in `setUp()` and cleaned up in `tearDown()`
class SentryInfoPlistWrapperTests: XCTestCase {
    
    private var sut: SentryInfoPlistWrapper!
    private var testBundle: Bundle!
    
    override func setUp() {
        super.setUp()
        
        // Create a test bundle with our custom Info.plist
        testBundle = TestBundle.createTestBundle()
        XCTAssertNotNil(testBundle, "Test bundle should be created successfully")
        
        sut = SentryInfoPlistWrapper(bundle: testBundle)
    }
    
    override func tearDownWithError() throws {
        try TestBundle.cleanup(testBundle)
        testBundle = nil
        sut = nil
        super.tearDown()
    }
    
    // MARK: - getAppValueString Tests
    
    func testGetAppValueString_whenKeyExists_shouldReturnValue() throws {
        // Arrange
        let key = "TestStringKey"
        
        // Act
        let value = try sut.getAppValueString(for: key)
        
        // Assert
        XCTAssertEqual(value, "TestStringValue", "Should return the correct string value")
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
        // TestArrayKey is an array in our test plist, not a string
        let key = "TestArrayKey"
        
        // Act & Assert
        XCTAssertThrowsError(try sut.getAppValueString(for: key)) { error in
            guard case SentryInfoPlistError.unableToCastValue(let errorKey, _, let type) = error else {
                XCTFail("Expected SentryInfoPlistError.unableToCastValue, got \(error)")
                return
            }
            XCTAssertEqual(errorKey, key)
            XCTAssertTrue(type == String.self)
        }
    }
    
    // MARK: - getAppValueBoolean Tests
    
    func testGetAppValueBoolean_whenKeyExistsAndIsTrue_shouldReturnTrue() {
        // Arrange
        let key = "TestBooleanTrue"
        var error: NSError?
        
        // Act
        let value = sut.getAppValueBoolean(for: key, errorPtr: &error)
        
        // Assert
        XCTAssertNil(error, "Should not have an error when reading a valid boolean")
        XCTAssertTrue(value, "Should return true for TestBooleanTrue key")
    }
    
    func testGetAppValueBoolean_whenKeyExistsAndIsFalse_shouldReturnFalse() {
        // Arrange
        let key = "TestBooleanFalse"
        var error: NSError?
        
        // Act
        let value = sut.getAppValueBoolean(for: key, errorPtr: &error)
        
        // Assert
        XCTAssertNil(error, "Should not have an error when reading a valid boolean")
        XCTAssertFalse(value, "Should return false for TestBooleanFalse key")
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
        // TestStringKey is a string, not a boolean
        let key = "TestStringKey"
        var error: NSError?
        
        // Act
        let value = sut.getAppValueBoolean(for: key, errorPtr: &error)
        
        // Assert
        XCTAssertFalse(value, "Should return false when value cannot be cast to Boolean")
        XCTAssertNotNil(error, "Error should be set when type casting fails")
    }
    
    func testGetAppValueBoolean_withNullErrorPointer_shouldNotCrash() {
        // Arrange
        let key = "TestStringKey" // A key that exists but is not a boolean
        
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
        let xcodeKey = SentryInfoPlistKey.xcodeVersion.rawValue
        
        // Act
        let value = try sut.getAppValueString(for: xcodeKey)
        
        // Assert
        XCTAssertEqual(value, "1610", "Should return the DTXcode value from test bundle")
    }
    
    func testGetAppValueBoolean_withSentryInfoPlistKey_shouldWork() {
        // Arrange
        let compatibilityKey = SentryInfoPlistKey.designRequiresCompatibility.rawValue
        var error: NSError?
        
        // Act
        let value = sut.getAppValueBoolean(for: compatibilityKey, errorPtr: &error)
        
        // Assert
        XCTAssertNil(error, "Should not have an error when reading a valid boolean")
        XCTAssertFalse(value, "Should return false for UIDesignRequiresCompatibility key")
    }
    
    // MARK: - Multiple Consecutive Calls
    
    func testMultipleConsecutiveCalls_shouldReturnConsistentResults() throws {
        // Arrange
        let key = "TestStringKey"
        
        // Act
        let value1 = try sut.getAppValueString(for: key)
        let value2 = try sut.getAppValueString(for: key)
        
        // Assert
        XCTAssertEqual(value1, value2, "Multiple calls should return the same value")
        XCTAssertEqual(value1, "TestStringValue")
    }
}
