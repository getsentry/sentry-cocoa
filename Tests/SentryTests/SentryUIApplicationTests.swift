@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)
class SentryUIApplicationTests: XCTestCase {
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func test_noScene_delegateWithNoWindow() {
        let sut = TestSentryUIApplication()
        XCTAssertEqual(sut.getWindows()?.count, 0)
    }

    func test_delegateWithWindow() {
        let sut = TestSentryUIApplication()
        let delegate = TestApplicationDelegate()
        sut.appDelegate = delegate
        sut.appDelegate?.window = UIWindow()

        XCTAssertEqual(sut.getWindows()?.count, 1)
    }

    func test_applicationWithScenes() {
        let sceneDelegate = TestUISceneDelegate()
        sceneDelegate.window = UIWindow()

        let scene1 = MockUIScene()
        scene1.delegate = sceneDelegate

        let sut = TestSentryUIApplication()
        sut.scenes = [scene1]

        XCTAssertEqual(sut.getWindows()?.count, 1)
    }

    func test_applicationWithScenesAndDelegateWithWindow_Unique() {
        let sceneDelegate = TestUISceneDelegate()
        sceneDelegate.window = UIWindow()
        let scene1 = MockUIScene()
        scene1.delegate = sceneDelegate

        let delegate = TestApplicationDelegate()
        delegate.window = UIWindow()

        let sut = TestSentryUIApplication()
        sut.scenes = [scene1]
        sut.appDelegate = delegate

        XCTAssertEqual(sut.getWindows()?.count, 2)
    }

    func test_applicationWithScenesAndDelegateWithWindow_Same() {
        let window = UIWindow()
        let sceneDelegate = TestUISceneDelegate()
        sceneDelegate.window = window
        let scene1 = MockUIScene()
        scene1.delegate = sceneDelegate

        let delegate = TestApplicationDelegate()
        delegate.window = window

        let sut = TestSentryUIApplication()
        sut.scenes = [scene1]
        sut.appDelegate = delegate

        XCTAssertEqual(sut.getWindows()?.count, 1)
    }

    func test_applicationWithScenes_noWindow() {
        let sceneDelegate = TestUISceneDelegate()

        let scene1 = MockUIScene()
        scene1.delegate = sceneDelegate

        let sut = TestSentryUIApplication()
        sut.scenes = [scene1]

        XCTAssertEqual(sut.getWindows()?.count, 0)
    }

    private class TestUISceneDelegate: NSObject, UIWindowSceneDelegate {
        var window: UIWindow?
    }
}
#endif
