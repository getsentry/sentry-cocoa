import XCTest

class UIViewControllerHelperTests: XCTestCase {
    
    func testSanitizeViewControllerNameWithBaseObject() {
        let object = NSObject()
        let name = UIViewControllerHelper.sanitizeViewControllerName(object)
        
        XCTAssertEqual(name, "NSObject")
    }
    
    func testSanitizeViewControllerNameWithSentryObject() {
        let object = Options()
        let name = UIViewControllerHelper.sanitizeViewControllerName(object)
        
        XCTAssertEqual(name, "SentryOptions")
    }
    
}
