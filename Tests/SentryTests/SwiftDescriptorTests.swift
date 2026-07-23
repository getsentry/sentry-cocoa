@_spi(Private) @testable import Sentry
import XCTest

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

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
        
        XCTAssertEqual(name, "Options")
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
        XCTAssertEqual("XMLParsingError(line: 10, column: 12, kind: \(SentryTestSetup.testPrefix).XMLParsingError.ErrorKind.internalError)", actual)
    }
    
    func testGetSwiftErrorDescription_StructWithOneParam() {
        let actual = SwiftDescriptor.getSwiftErrorDescription(StructWithOneParam(line: 10))
        XCTAssertEqual("StructWithOneParam(line: 10)", actual)
    }
    
    private func sanitize(_ name: AnyObject) -> String {
        return SwiftDescriptor.getObjectClassName(name)
    }

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
    func testGetSanitizedViewDescription_neverContainsCoordinates() {
        // Coordinates are a potential security risk, as they can leak which key a
        // user tapped on custom PIN code views, so they must never be included.
        // -- Arrange --
        let view = UIView()
        view.frame = CGRect(x: 42, y: 240, width: 375, height: 812)

        // -- Act --
        let description = SwiftDescriptor.getSanitizedViewDescription(view)

        // -- Assert --
        XCTAssertFalse(description.contains("frame"), description)
        XCTAssertFalse(description.contains("42"), description)
        XCTAssertFalse(description.contains("240"), description)
        XCTAssertFalse(description.contains("375"), description)
        XCTAssertFalse(description.contains("812"), description)
    }

    func testGetSanitizedViewDescription_containsClassNameAndPointer() {
        // -- Arrange --
        let view = UIButton()

        // -- Act --
        let description = SwiftDescriptor.getSanitizedViewDescription(view)

        // -- Assert --
        XCTAssertTrue(description.hasPrefix("<UIButton: 0x"), description)
        XCTAssertTrue(description.hasSuffix(">"), description)
    }

    func testGetSanitizedViewDescription_reportsCustomSubclassName() {
        // -- Arrange --
        let view = PinCodeButton()

        // -- Act --
        let description = SwiftDescriptor.getSanitizedViewDescription(view)

        // -- Assert --
        XCTAssertTrue(description.contains("PinCodeButton"), description)
    }

    func testGetSanitizedViewDescription_usesSwiftBooleanForOpaque() {
        // -- Arrange --
        let opaqueView = UIView()
        opaqueView.isOpaque = true
        let transparentView = UIView()
        transparentView.isOpaque = false

        // -- Act --
        let opaqueDescription = SwiftDescriptor.getSanitizedViewDescription(opaqueView)
        let transparentDescription = SwiftDescriptor.getSanitizedViewDescription(transparentView)

        // -- Assert --
        XCTAssertTrue(opaqueDescription.contains("opaque = true"), opaqueDescription)
        XCTAssertTrue(transparentDescription.contains("opaque = false"), transparentDescription)
    }

    func testGetSanitizedViewDescription_includesHiddenOnlyWhenHidden() {
        // -- Arrange --
        let visibleView = UIView()
        visibleView.isHidden = false
        let hiddenView = UIView()
        hiddenView.isHidden = true

        // -- Act --
        let visibleDescription = SwiftDescriptor.getSanitizedViewDescription(visibleView)
        let hiddenDescription = SwiftDescriptor.getSanitizedViewDescription(hiddenView)

        // -- Assert --
        XCTAssertFalse(visibleDescription.contains("hidden"), visibleDescription)
        XCTAssertTrue(hiddenDescription.contains("hidden = true"), hiddenDescription)
    }

    private class PinCodeButton: UIButton {}
#endif
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
