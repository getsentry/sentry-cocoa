@_spi(Private) @testable import Sentry
import XCTest

class SentrySDKSettingsTests: XCTestCase {
    
    // MARK: - initWithOptions tests
    
    func testInitWithOptions_WhenOptionsNil_ReturnsDefaultSettings() {
        let settings = SentrySDKSettings(options: nil)
        
        XCTAssertNotNil(settings)
        XCTAssertFalse(settings.autoInferIP)
    }
    
    func testInitWithOptions_WhenSendDefaultPiiTrue_SetsAutoInferIPToTrue() {
        let options = try! SentryOptionsInternal.initWithDict([
            "dsn": "https://username:password@app.getsentry.com/12345",
            "sendDefaultPii": true
        ])
        
        XCTAssertNotNil(options)
        
        let settings = SentrySDKSettings(options: options)
        
        XCTAssertNotNil(settings)
        XCTAssertTrue(settings.autoInferIP)
    }
    
    func testInitWithOptions_WhenSendDefaultPiiFalse_SetsAutoInferIPToFalse() {
        let options = try! SentryOptionsInternal.initWithDict([
            "dsn": "https://username:password@app.getsentry.com/12345",
            "sendDefaultPii": false
        ])
        
        XCTAssertNotNil(options)
        
        let settings = SentrySDKSettings(options: options)
        
        XCTAssertNotNil(settings)
        XCTAssertFalse(settings.autoInferIP)
    }
    
    // MARK: - initWithDict tests
    
    func testInitWithDict_WhenInferIpIsAuto_SetsAutoInferIPToTrue() {
        let settings = SentrySDKSettings(dict: [
            "infer_ip": "auto"
        ])
        
        XCTAssertNotNil(settings)
        XCTAssertTrue(settings.autoInferIP)
    }
    
    func testInitWithDict_WhenInferIpIsNever_SetsAutoInferIPToFalse() {
        let settings = SentrySDKSettings(dict: [
            "infer_ip": "never"
        ])
        
        XCTAssertNotNil(settings)
        XCTAssertFalse(settings.autoInferIP)
    }
    
    func testInitWithDict_WhenInferIpIsInvalidString_SetsAutoInferIPToFalse() {
        let settings = SentrySDKSettings(dict: [
            "infer_ip": "invalid_value"
        ])
        
        XCTAssertNotNil(settings)
        XCTAssertFalse(settings.autoInferIP)
    }
    
    func testInitWithDict_WhenInferIpIsNotString_SetsAutoInferIPToFalse() {
        let settings = SentrySDKSettings(dict: [
            "infer_ip": true
        ])
        
        XCTAssertNotNil(settings)
        XCTAssertFalse(settings.autoInferIP)
    }
    
    func testInitWithDict_WhenInferIpKeyMissing_SetsAutoInferIPToFalse() {
        let settings = SentrySDKSettings(dict: [:])
        
        XCTAssertNotNil(settings)
        XCTAssertFalse(settings.autoInferIP)
    }
    
    func testInitWithDict_WhenInferIpIsNil_SetsAutoInferIPToFalse() {
        let settings = SentrySDKSettings(dict: [
            "infer_ip": NSNull()
        ])
        
        XCTAssertNotNil(settings)
        XCTAssertFalse(settings.autoInferIP)
    }
    
    // MARK: - serialize tests
    
    func testSerialize_WhenAutoInferIPIsTrue_ReturnsCorrectDictionary() {
        let settings = SentrySDKSettings(dict: [
            "infer_ip": "auto"
        ])
        
        let serialized = settings.serialize()
        
        XCTAssertNotNil(serialized)
        XCTAssertEqual(serialized["infer_ip"] as? String, "auto")
    }
    
    func testSerialize_WhenAutoInferIPIsFalse_ReturnsCorrectDictionary() {
        let settings = SentrySDKSettings(dict: [
            "infer_ip": "never"
        ])
        
        let serialized = settings.serialize()
        
        XCTAssertNotNil(serialized)
        XCTAssertEqual(serialized["infer_ip"] as? String, "never")
    }
    
    func testSerialize_WhenAutoInferIPIsSetDirectly_ReturnsCorrectDictionary() {
        let settings = SentrySDKSettings()
        settings.autoInferIP = true
        
        let serialized = settings.serialize()
        
        XCTAssertNotNil(serialized)
        XCTAssertEqual(serialized["infer_ip"] as? String, "auto")
    }
    
    func testSerialize_WhenAutoInferIPIsSetToFalseDirectly_ReturnsCorrectDictionary() {
        let settings = SentrySDKSettings()
        settings.autoInferIP = false
        
        let serialized = settings.serialize()
        
        XCTAssertNotNil(serialized)
        XCTAssertEqual(serialized["infer_ip"] as? String, "never")
    }
    
    // MARK: - autoInferIP property tests
    
    func testAutoInferIPProperty_CanBeSetAndRetrieved() {
        let settings = SentrySDKSettings()
        
        // Test default value
        XCTAssertFalse(settings.autoInferIP)
        
        // Test setting to true
        settings.autoInferIP = true
        XCTAssertTrue(settings.autoInferIP)
        
        // Test setting to false
        settings.autoInferIP = false
        XCTAssertFalse(settings.autoInferIP)
    }
    
    // MARK: - edge case tests
    
    func testEdgeCase_EmptyDictionaryInitialization() {
        let settings = SentrySDKSettings(dict: [:])
        
        XCTAssertNotNil(settings)
        XCTAssertFalse(settings.autoInferIP)
    }
    
    func testEdgeCase_NonStringValuesInDictionary() {
        let settings = SentrySDKSettings(dict: [
            "infer_ip": 42,
            "other_key": "value"
        ])
        
        XCTAssertNotNil(settings)
        XCTAssertFalse(settings.autoInferIP)
    }
    
    func testEdgeCase_CaseSensitiveInferIpValues() {
        let settings1 = SentrySDKSettings(dict: ["infer_ip": "AUTO"])
        let settings2 = SentrySDKSettings(dict: ["infer_ip": "Auto"])
        let settings3 = SentrySDKSettings(dict: ["infer_ip": "auto"])
        
        XCTAssertFalse(settings1.autoInferIP) // Should be case sensitive
        XCTAssertFalse(settings2.autoInferIP) // Should be case sensitive
        XCTAssertTrue(settings3.autoInferIP)  // Exact match should work
    }
} 
