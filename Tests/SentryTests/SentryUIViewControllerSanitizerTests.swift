import Sentry
import XCTest

#if os(iOS)
class SentryUIViewControllerSanitizerTests: XCTestCase {
    
    private class PrivateViewController: UIViewController {
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
    
    func testSanitizeViewControllerNameWithStrings() {
        let viewController = UIViewController()
        let privateViewController = PrivateViewController()
        
        XCTAssertEqual(
            "UIViewController", sanitize(viewController)
        )
        
        let swiftDescriptor = SwiftDescriptor()
        SentryDependencyContainer.sharedInstance.register(SentryDescriptorProtocol.self) {
            return swiftDescriptor
        }
        
        XCTAssertEqual(
            "PrivateViewController", sanitize(privateViewController)
        )
    }
    
    private func sanitize(_ name: Any) -> String {
        return SentryUIViewControllerSanitizer.sanitizeViewControllerName(name)
    }
}
#endif
