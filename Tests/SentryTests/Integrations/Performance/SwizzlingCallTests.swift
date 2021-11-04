import XCTest

//Run swizzled function because if one of those funcions does not
//call the original implementation an exception is thrown.
class SwizzlingCallTests: XCTestCase {
 
    override func setUp() {
        super.setUp()
        initSDKForSwizzling()
    }
    
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    func testViewController_SwizzlingCall() {
        let testViewController = TestViewController()
        testViewController.viewDidLoad()
        testViewController.viewWillLayoutSubviews()
        testViewController.viewDidLayoutSubviews()
        testViewController.viewWillAppear(false)
        testViewController.viewWillDisappear(false)
        testViewController.viewDidAppear(false)
        
        let viewController = UIViewController()
        viewController.loadView()
        viewController.viewDidAppear(false)
    }
    
#endif
    
    func testSwizzling() {
        let task = URLSession.shared.dataTask(with: URL(string: "http://localhost/")!)
        task.resume()
        
        let _ = URLSessionConfiguration.default.httpAdditionalHeaders
    }
    
    private func initSDKForSwizzling() {
        SentrySDK.start { options in
            options.dsn = ""
            options.tracesSampleRate = 1.0
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            let n = class_getImageName(TestViewController.self)
            let s = NSString(cString: n!, encoding: String.Encoding.utf8.rawValue)
            options.add(inAppInclude: s!.lastPathComponent)
#endif
        }
    }
}
