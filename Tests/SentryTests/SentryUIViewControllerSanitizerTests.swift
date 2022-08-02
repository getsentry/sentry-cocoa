import XCTest

class SentryUIViewControllerSanitizerTests: XCTestCase {
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
     private class SomeViewController: UIViewController {
     }
 #endif
    
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
    
    func testSanitizeViewControllerNameWithStrings() {
        XCTAssertEqual(
            "sentry_ios_cocoapods.ViewController", sanitize("<sentry_ios_cocoapods.ViewController: 0x7fd9201253c0>")
        )
        
        XCTAssertEqual(
            "sentry_ios_cocoapodsViewController: 0x7fd9201253c0", sanitize("sentry_ios_cocoapodsViewController: 0x7fd9201253c0")
        )
        
        XCTAssertEqual(
            "sentry_ios_cocoapods.ViewController.miau", sanitize("<sentry_ios_cocoapods.ViewController.miau: 0x7fd9201253c0>")
        )
        
    }
    
#if (os(iOS) && !targetEnvironment(macCatalyst)) || os(tvOS)
     func testSanitize_mangledViewController() {
         let vc = SomeViewController()
         XCTAssertEqual("SentryTests.SentryUIViewControllerSanitizerTests.SomeViewController", sanitize(vc))
     }
 #endif
    
    private func sanitize(_ name: Any) -> String {
        return SentryUIViewControllerSanitizer.sanitizeViewControllerName(name)
    }
}
