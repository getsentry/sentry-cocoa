import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryUIApplicationTests: XCTestCase {

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
    func test_applicationWithScenes_noWindow() {
        let sceneDelegate = TestUISceneDelegate()

        let scene1 = MockUIScene()
        scene1.delegate = sceneDelegate

        let sut = MockSentryUIApplicationTests()
        sut.scenes = [scene1]

        XCTAssertEqual(sut.windows?.count, 0)
    }

    private class TestApplicationDelegate: NSObject, UIApplicationDelegate {
        var window: UIWindow?
    }

    private class TestUISceneDelegate: NSObject, UIWindowSceneDelegate {
        var window: UIWindow?
    }

    private class MockSentryUIApplicationTests: SentryUIApplication {
        weak var appDelegate: TestApplicationDelegate?

        var scenes: [Any]?

        override func getDelegate(_ application: UIApplication) -> UIApplicationDelegate? {
            return appDelegate
        }

        @available(iOS 13.0, tvOS 13.0, *)
        override func getConnectedScenes(_ application: UIApplication) -> [UIScene] {
            return scenes as? [UIScene] ?? super.getConnectedScenes(application)
        }
    }
}
#endif
