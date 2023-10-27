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
    
    func testGetSwiftErrorDescription_EnumValue() {
        let actual = SwiftDescriptor.getSwiftErrorDescription(LoginError.wrongPassword)
        XCTAssertEqual("wrongPassword", actual)
    }
    
    func testGetSwiftErrorDescription_EnumValueWithData() {
        let actual = SwiftDescriptor.getSwiftErrorDescription(LoginError.wrongUser(name: "Max"))
        XCTAssertEqual("wrongUser(name: \"Max\")", actual)
    }
    
    func testGetSwiftErrorDescription_StructWithData() {
        let actual = SwiftDescriptor.getSwiftErrorDescription(XMLParsingError(line: 10, column: 12, kind: .internalError))
        XCTAssertEqual("XMLParsingError(line: 10, column: 12, kind: SentryTests.XMLParsingError.ErrorKind.internalError)", actual)
    }
    
    func testGetSwiftErrorDescription_StructWithOneParam() {
        let actual = SwiftDescriptor.getSwiftErrorDescription(StructWithOneParam(line: 10))
        XCTAssertEqual("StructWithOneParam(line: 10)", actual)
    }
    
    private func sanitize(_ name: AnyObject) -> String {
        return SwiftDescriptor.getObjectClassName(name)
    }
}

enum LoginError: Error {
    case wrongUser(name: String)
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
    let line: Int
}
