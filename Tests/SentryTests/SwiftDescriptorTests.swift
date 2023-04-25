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
    
    func testgetSwiftErrorDescription_EnumValue() {
        let actual = SwiftDescriptor.getSwiftErrorDescription(SentryTestError.someError)
        XCTAssertEqual("someError", actual)
    }
    
    func testgetSwiftErrorDescription_EnumValueWithData() {
        let actual = SwiftDescriptor.getSwiftErrorDescription(SentryTestError.someOhterError(10))
        XCTAssertEqual("someOhterError", actual)
    }
    
    func testgetSwiftErrorDescription_StructWithData() {
        let actual = SwiftDescriptor.getSwiftErrorDescription(XMLParsingError(line: 10, column: 12, kind: .internalError))
        XCTAssertNil(actual)
        
        SentrySDK.capture(error: LoginError.wrongPassword)
    }
    
    func testgetSwiftErrorDescription_StructWithOneParam() {
        let actual = SwiftDescriptor.getSwiftErrorDescription(StructWithOneParam(line: 10))
        XCTAssertNil(actual)
    }
    
    private func sanitize(_ name: AnyObject) -> String {
        return SwiftDescriptor.getObjectClassName(name)
    }
}

enum SentryTestError: Error {
    case someError
    case someOhterError(Int)
}

enum LoginError: Error {
    case wrongUser
    case wrongPassword
}

struct XMLParsingError: Error {
    enum ErrorKind {
        case invalidCharacter
        case mismatchedTag
        case internalError
    }

    let line: Int
    let column: Int
    let kind: ErrorKind
}

struct StructWithOneParam: Error {
    enum ErrorKind {
        case invalidCharacter
        case mismatchedTag
        case internalError
    }

    let line: Int
}
