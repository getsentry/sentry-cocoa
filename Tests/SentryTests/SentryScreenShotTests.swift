import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryScreenShotTests: XCTestCase {
    private class Fixture {
        
        let uiApplication = TestSentryUIApplication()
        
        var sut: SentryScreenshot {
            return SentryScreenshot()
        }
    }
    
    private var fixture: Fixture!
    
    override func setUp() {
        super.setUp()
        fixture = Fixture()
        SentryDependencyContainer.sharedInstance().application = fixture.uiApplication
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func test_IsMainThread() {
        let testWindow = TestWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        var isMainThread = false
        
        testWindow.onDrawHierarchy = {
            isMainThread = Thread.isMainThread
        }
        
        fixture.uiApplication.windows = [testWindow]
        
        let queue = DispatchQueue(label: "TestQueue")
        
        let expect = expectation(description: "Screenshot")
        let _ = queue.async {
            self.fixture.sut.appScreenshots()
            expect.fulfill()
        }
                
        wait(for: [expect], timeout: 1)
        XCTAssertTrue(isMainThread)
    }
    
    func test_Draw_Each_Window() {
        let firstWindow = TestWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        let secondWindow = TestWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        var drawFirstWindow = false
        var drawSecondWindow = false
        
        firstWindow.onDrawHierarchy = {
            drawFirstWindow = true
        }
        secondWindow.onDrawHierarchy = {
            drawSecondWindow = true
        }
        
        fixture.uiApplication.windows = [firstWindow, secondWindow]
        
        self.fixture.sut.appScreenshots()
        
        XCTAssertTrue(drawFirstWindow)
        XCTAssertTrue(drawSecondWindow)
    }
    
    func test_image_size() {
        let testWindow = TestWindow(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        fixture.uiApplication.windows = [testWindow]
        
        guard let data = self.fixture.sut.appScreenshots() else {
            XCTFail("Could not make window screenshot")
            return
        }
        
        let image = UIImage(data: data[0])
        
        XCTAssertEqual(image?.size.width, 10)
        XCTAssertEqual(image?.size.height, 10)
        
    }
    
    class TestSentryUIApplication: SentryUIApplication {
        private var _windows: [UIWindow]?
        
        override var windows: [UIWindow]? {
            get {
                return _windows
            }
            set {
                _windows = newValue
            }
        }
    }

    class TestWindow: UIWindow {
        var onDrawHierarchy: (() -> Void)?
        
        override func drawHierarchy(in rect: CGRect, afterScreenUpdates afterUpdates: Bool) -> Bool {
            onDrawHierarchy?()
            return true
        }
    }
   
}
#endif
