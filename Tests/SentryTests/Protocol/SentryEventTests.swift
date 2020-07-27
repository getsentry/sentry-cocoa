import XCTest

class SentryEventTests: XCTestCase {
    
    private let keyToSanitize = "sanitizeKey"

    func testSerialize_Sdk() {
        let expected = ["version": "1.0.0"]
        
        let event = Event()
        event.sdk = expected
        
        let actual = event.serialize()["sdk"] as! [String: Any]
        XCTAssertEqual(expected["version"], actual["version"] as? String)
    }
    
    func testSerialize_SdkIsSanitized() {
        let event = Event()
        event.sdk = getDictToSanitize()
        
        let actual = event.serialize()["sdk"] as! [String: Any]
        assertValueIsSanitized(dict: actual)
    }
    
    func testSerialize_ExtraIsSanitized() {
        let event = Event()
        event.extra = getDictToSanitize()
        
        let actual = event.serialize()["extra"] as! [String: Any]
        assertValueIsSanitized(dict: actual)
    }
    
    private func getDictToSanitize() -> [String: Any] {
        // When using a custom class as a value in the dict sentry_sanitize sets
        // the NSObject.description of the custom class as the value.
        return [keyToSanitize: CustomDescription()]
    }
    
    private func assertValueIsSanitized(dict: [String: Any]) {
        XCTAssertEqual(CustomDescription().description, dict[keyToSanitize] as? String)
    }
}

/**
 * We need to override CustomStringConvertible to be able to override NSObject.description.
 */
class CustomDescription: CustomStringConvertible {
     var description: String {
        return "sanitize"
    }
}
