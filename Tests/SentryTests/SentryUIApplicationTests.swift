@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryUIApplicationTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func test_noScene_delegateWithNoWindow() {
        let sut = MockSentryUIApplicationTests()
        XCTAssertEqual(sut.windows?.count, 0)
    }

    func test_delegateWithWindow() {
        let sut = MockSentryUIApplicationTests()
        let delegate = TestApplicationDelegate()
        sut.appDelegate = delegate
        sut.appDelegate?.window = UIWindow()

        XCTAssertEqual(sut.windows?.count, 1)
    }

    //Somehow this is running under iOS 12 and is breaking the test. Disabling it.
    @available(iOS 13.0, tvOS 13.0, *)
    func test_applicationWithScenes() {
        let sceneDelegate = TestUISceneDelegate()
        sceneDelegate.window = UIWindow()

        let scene1 = MockUIScene()
        scene1.delegate = sceneDelegate

        let sut = MockSentryUIApplicationTests()
        sut.scenes = [scene1]

        XCTAssertEqual(sut.windows?.count, 1)
    }

    //Somehow this is running under iOS 12 and is breaking the test. Disabling it.
    @available(iOS 13.0, tvOS 13.0, *)
    func test_applicationWithScenesAndDelegateWithWindow_Unique() {
        let sceneDelegate = TestUISceneDelegate()
        sceneDelegate.window = UIWindow()
        let scene1 = MockUIScene()
        scene1.delegate = sceneDelegate

        let delegate = TestApplicationDelegate()
        delegate.window = UIWindow()

        let sut = MockSentryUIApplicationTests()
        sut.scenes = [scene1]
        sut.appDelegate = delegate

        XCTAssertEqual(sut.windows?.count, 2)
    }

    //Somehow this is running under iOS 12 and is breaking the test. Disabling it.
    @available(iOS 13.0, tvOS 13.0, *)
    func test_applicationWithScenesAndDelegateWithWindow_Same() {
        let window = UIWindow()
        let sceneDelegate = TestUISceneDelegate()
        sceneDelegate.window = window
        let scene1 = MockUIScene()
        scene1.delegate = sceneDelegate

        let delegate = TestApplicationDelegate()
        delegate.window = window

        let sut = MockSentryUIApplicationTests()
        sut.scenes = [scene1]
        sut.appDelegate = delegate

        XCTAssertEqual(sut.windows?.count, 1)
    }

    //Somehow this is running under iOS 12 and is breaking the test. Disabling it.
    @available(iOS 13.0, tvOS 13.0, *)
    func test_applicationWithScenes_noWindow() {
        let sceneDelegate = TestUISceneDelegate()

        let scene1 = MockUIScene()
        scene1.delegate = sceneDelegate

        let sut = MockSentryUIApplicationTests()
        sut.scenes = [scene1]

        XCTAssertEqual(sut.windows?.count, 0)
    }
    
    @available(iOS 13.0, tvOS 13.0, *)
    func test_ApplicationState() {
        let sut = MockSentryUIApplicationTests()
        sut.notificationCenterWrapper.ignoreRemoveObserver = true
        XCTAssertEqual(sut.applicationState, .active)
        
        sut.notificationCenterWrapper.addObserverWithObjectInvocations.invocations.forEach { (observer: WeakReference<NSObject>, selector: Selector, name: NSNotification.Name?, _: Any?) in
            if name == UIApplication.didEnterBackgroundNotification {
                sut.perform(selector, with: observer)
            }
        }
        
        XCTAssertEqual(sut.applicationState, .background)
        
        sut.notificationCenterWrapper.addObserverWithObjectInvocations.invocations.forEach { (observer: WeakReference<NSObject>, selector: Selector, name: NSNotification.Name?, _: Any?) in
            if name == UIApplication.didBecomeActiveNotification {
                sut.perform(selector, with: observer)
            }
        }
        
        XCTAssertEqual(sut.applicationState, .active)
    }

    private class TestApplicationDelegate: NSObject, UIApplicationDelegate {
        var window: UIWindow?
    }

    private class TestUISceneDelegate: NSObject, UIWindowSceneDelegate {
        var window: UIWindow?
    }

    private class MockSentryUIApplicationTests: SentryUIApplication {

        let notificationCenterWrapper: TestNSNotificationCenterWrapper

        weak var appDelegate: TestApplicationDelegate?
        var scenes: [Any]?

        init() {
            notificationCenterWrapper = TestNSNotificationCenterWrapper()
            super.init(notificationCenterWrapper: notificationCenterWrapper, dispatchQueueWrapper: TestSentryDispatchQueueWrapper())
        }

        override func getDelegate(_ application: UIApplication) -> UIApplicationDelegate? {
            return appDelegate
        }
    }
}
#endif
