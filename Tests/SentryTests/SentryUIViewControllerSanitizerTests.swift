import XCTest

class SentryUIViewControllerSanitizerTests: XCTestCase {
    
    func testSanitizeViewControllerNameWithBaseObject() {
        let object = NSObject()
        let name = SentryUIViewControllerSanitizer.sanitizeViewControllerName(object)
        
        XCTAssertEqual(name, "NSObject")
    }
    
    func testSanitizeViewControllerNameWithSentryObject() {
        let object = Options()
        let name = SentryUIViewControllerSanitizer.sanitizeViewControllerName(object)
        
        XCTAssertEqual(name, "SentryOptions")
    }
}
