@testable import Sentry
import XCTest

// MARK: - Test Classes for Property Extraction

/// Simple class with a single stored property.
private class SinglePropertyClass: NSObject {
    @objc var name: String = ""
}

/// Class with multiple stored properties.
private class MultiplePropertiesClass: NSObject {
    @objc var firstName: String = ""
    @objc var lastName: String = ""
    @objc var age: Int = 0
}

/// Class with a computed property.
private class ComputedPropertyClass: NSObject {
    private var _value: Int = 0
    
    @objc var value: Int {
        get { _value }
        set { _value = newValue }
    }
}

/// Class with Swift-only stored properties (not exposed to Objective-C).
private class SwiftOnlyPropertiesClass: NSObject {
    var swiftStoredProperty: String = ""
    var anotherSwiftProperty: Int = 0
}

/// Class with mixed @objc and Swift-only properties.
private class MixedPropertiesClass: NSObject {
    @objc var objcProperty: String = ""
    var swiftOnlyProperty: Int = 0
}

/// Empty class with no properties.
private class EmptyClass: NSObject {}

// MARK: - Tests

final class PropertyExtractorTests: XCTestCase {
    
    // MARK: - @objc Property Tests
    
    func testExtractPropertyNames_whenSingleObjcProperty_shouldExtractIt() {
        let result = extractPropertyNames(from: SinglePropertyClass())
        
        XCTAssertTrue(result.contains("name"))
    }
    
    func testExtractPropertyNames_whenMultipleObjcProperties_shouldExtractAll() {
        let result = extractPropertyNames(from: MultiplePropertiesClass())
        
        XCTAssertTrue(result.contains("firstName"))
        XCTAssertTrue(result.contains("lastName"))
        XCTAssertTrue(result.contains("age"))
    }
    
    func testExtractPropertyNames_whenComputedObjcProperty_shouldExtractIt() {
        let result = extractPropertyNames(from: ComputedPropertyClass())
        
        // Should extract the computed property, not the private backing store
        XCTAssertTrue(result.contains("value"), "Should contain the computed property 'value'")
        XCTAssertFalse(result.contains("_value"), "Should not contain the private backing store '_value'")
    }
    
    // MARK: - Swift-Only Property Tests
    
    func testExtractPropertyNames_whenSwiftOnlyProperties_shouldExtractThem() {
        let result = extractPropertyNames(from: SwiftOnlyPropertiesClass())
        
        XCTAssertTrue(result.contains("swiftStoredProperty"), "Should contain Swift-only stored property")
        XCTAssertTrue(result.contains("anotherSwiftProperty"), "Should contain another Swift-only property")
    }
    
    // MARK: - Mixed Property Tests
    
    func testExtractPropertyNames_whenMixedProperties_shouldExtractBoth() {
        let result = extractPropertyNames(from: MixedPropertiesClass())
        
        XCTAssertTrue(result.contains("objcProperty"), "Should contain @objc property")
        XCTAssertTrue(result.contains("swiftOnlyProperty"), "Should contain Swift-only property")
    }
    
    // MARK: - Edge Case Tests
    
    func testExtractPropertyNames_whenEmptyClass_shouldReturnEmpty() {
        let result = extractPropertyNames(from: EmptyClass())
        
        XCTAssertTrue(result.isEmpty)
    }
    
    func testExtractPropertyNames_shouldReturnConsistentResults() {
        let options = Options()
        let result1 = extractPropertyNames(from: options)
        let result2 = extractPropertyNames(from: options)
        
        XCTAssertEqual(result1, result2, "Multiple calls should return the same properties")
    }
    
    // MARK: - Options Class Tests
    
    func testExtractPropertyNames_whenOptions_shouldReturnKnownProperties() {
        let result = extractPropertyNames(from: Options())
        
        // Verify some well-known Options properties are extracted
        XCTAssertTrue(result.contains("dsn"), "Should contain dsn property")
        XCTAssertTrue(result.contains("debug"), "Should contain debug property")
        XCTAssertTrue(result.contains("environment"), "Should contain environment property")
        XCTAssertTrue(result.contains("releaseName"), "Should contain releaseName property")
        XCTAssertTrue(result.contains("dist"), "Should contain dist property")
        XCTAssertTrue(result.contains("enabled"), "Should contain enabled property")
        XCTAssertTrue(result.contains("maxBreadcrumbs"), "Should contain maxBreadcrumbs property")
        XCTAssertTrue(result.contains("beforeSend"), "Should contain beforeSend property")
        XCTAssertTrue(result.contains("sampleRate"), "Should contain sampleRate property")
    }
    
    func testExtractPropertyNames_whenOptions_shouldNotBeEmpty() {
        let result = extractPropertyNames(from: Options())
        
        XCTAssertFalse(result.isEmpty, "Should extract at least some properties from Options")
        XCTAssertGreaterThan(result.count, 10, "Options should have more than 10 properties")
    }
}
