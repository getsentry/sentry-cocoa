import XCTest

class SwiftDescriptorTests: XCTestCase {

    private class InnerClass: NSObject {
        
    }
    
    func testDescriptionWithBaseObject() {
        let object = NSObject()
        let name = sanitize(object)
        
        XCTAssertEqual(name, "NSObject")
    }
    
    func testDescriptionWithSentryObject() {
        let object = Options()
        let name = sanitize(object)
        
        XCTAssertEqual(name, "SentryOptions")
    }
    
    func testDescriptionWithPrivateSwiftClass() {
        let object = InnerClass()
        let name = sanitize(object)
        
        XCTAssertNotEqual(name, object.description)
        XCTAssertEqual(name, "InnerClass")
    }
    
    private func sanitize(_ name: AnyObject) -> String {
        return SwiftDescriptor.getObjectClassName(name)
    }
}
