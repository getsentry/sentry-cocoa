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

/// Class with no @objc properties (only Swift properties).
private class NoObjcPropertiesClass: NSObject {
    var swiftOnlyProperty: String = ""
}

/// Empty class with no properties.
private class EmptyClass: NSObject {}

// MARK: - Tests

final class ObjcPropertyExtractorTests: XCTestCase {
    
    private let sut = ObjcPropertyExtractor()
    
    // MARK: - extractPropertyNames Tests with Mock Classes
    
    func testExtractPropertyNames_whenSingleProperty_shouldExtractIt() {
        let result = sut.extractPropertyNames(from: SinglePropertyClass.self)
        
        XCTAssertEqual(result, ["name"])
    }
    
    func testExtractPropertyNames_whenMultipleProperties_shouldExtractAll() {
        let result = sut.extractPropertyNames(from: MultiplePropertiesClass.self)
        
        XCTAssertEqual(result, ["firstName", "lastName", "age"])
    }
    
    func testExtractPropertyNames_whenComputedProperty_shouldExtractIt() {
        let result = sut.extractPropertyNames(from: ComputedPropertyClass.self)
        
        // Should extract the computed property, not the private backing store
        XCTAssertTrue(result.contains("value"), "Should contain the computed property 'value'")
        XCTAssertFalse(result.contains("_value"), "Should not contain the private backing store '_value'")
    }
    
    func testExtractPropertyNames_whenNoObjcProperties_shouldReturnEmpty() {
        let result = sut.extractPropertyNames(from: NoObjcPropertiesClass.self)
        
        XCTAssertFalse(result.contains("swiftOnlyProperty"), "Should not contain Swift-only properties")
    }
    
    func testExtractPropertyNames_whenEmptyClass_shouldReturnEmpty() {
        let result = sut.extractPropertyNames(from: EmptyClass.self)
        
        XCTAssertTrue(result.isEmpty)
    }
    
    // MARK: - extractPropertyNames Tests with Options Class
    
    func testExtractPropertyNames_whenOptions_shouldReturnKnownProperties() {
        let result = sut.extractPropertyNames()
        
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
        let result = sut.extractPropertyNames()
        
        XCTAssertFalse(result.isEmpty, "Should extract at least some properties from Options")
        XCTAssertGreaterThan(result.count, 10, "Options should have more than 10 properties")
    }
    
    func testExtractPropertyNames_shouldReturnConsistentResults() {
        let result1 = sut.extractPropertyNames()
        let result2 = sut.extractPropertyNames()
        
        XCTAssertEqual(result1, result2, "Multiple calls should return the same properties")
    }
}
