import XCTest

#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
class SentryUIApplicationTests: XCTestCase {

    func test_noScene_delegateWithNoWindow() {
        let sut = MockSentryUIapplicationTests()
        XCTAssertEqual(sut.windows?.count, 0)
    }

    func test_delegateWithWindow() {
        let sut = MockSentryUIapplicationTests()
        sut.appDelegate.window = UIWindow()

        XCTAssertEqual(sut.windows?.count, 1)
    }

    @available(iOS 13.0, *)
    func test_applicationWithScenes() {
        let sceneDelegate = TestUISceneDelegate()
        sceneDelegate.window = UIWindow()

        let scene1 = MockUIScene()
        scene1.delegate = sceneDelegate

        let sut = MockSentryUIapplicationTests()
        sut.scenes = [scene1]

        XCTAssertEqual(sut.windows?.count, 1)
    }

    @available(iOS 13.0, *)
    func test_applicationWithScenes_noWindow() {
        let sceneDelegate = TestUISceneDelegate()

        let scene1 = MockUIScene()
        scene1.delegate = sceneDelegate

        let sut = MockSentryUIapplicationTests()
        sut.scenes = [scene1]

        XCTAssertEqual(sut.windows?.count, 0)
    }

    private class TestApplicationDelegate: NSObject, UIApplicationDelegate {
        var window: UIWindow?
    }

    private class TestUISceneDelegate: NSObject, UIWindowSceneDelegate {
        var window: UIWindow?
    }

    private class MockSentryUIapplicationTests: SentryUIApplication {
        weak var appDelegate = TestApplicationDelegate()

        var scenes: [Any]?

        override func getDelegate(_ application: UIApplication) -> UIApplicationDelegate? {
            return appDelegate
        }

        override func getConnectedScenes(_ application: UIApplication) -> [Any]? {
            return scenes ?? super.getConnectedScenes(application)
        }
    }
}
#endif
