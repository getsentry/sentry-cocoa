import XCTest

class SentryUIViewControllerSanitizerTests: XCTestCase {

    private class InnerClass: NSObject {
        
    }
    
    func testSanitizeViewControllerNameWithBaseObject() {
        let object = NSObject()
        let name = sanitize(object)
        
        XCTAssertEqual(name, "NSObject")
    }
    
    func testSanitizeViewControllerNameWithSentryObject() {
        let object = Options()
        let name = sanitize(object)
        
        XCTAssertEqual(name, "SentryOptions")
    }
    
    func testSanitizeViewControllerNameWithPrivateSwiftClass() {
        let object = InnerClass()
        let name = sanitize(object)
        
        XCTAssertNotEqual(name, object.description)
        XCTAssertEqual(name, "InnerClass")
    }
    
    private func sanitize(_ name: AnyObject) -> String {
        return SwiftDescriptor.getObjectClassName(name)
    }
}
