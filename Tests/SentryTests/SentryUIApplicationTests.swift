@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(tvOS)
class SentryUIApplicationTests: XCTestCase {

    private static let mockWindowScene: UIWindowScene = MockUIWindowScene()

    private func makeWindow() -> UIWindow {
        UIWindow(windowScene: Self.mockWindowScene)
    }

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
        sut.appDelegate?.window = makeWindow()

        XCTAssertEqual(sut.getWindows()?.count, 1)
    }

    func test_applicationWithScenes() {
        let sceneDelegate = TestUISceneDelegate()
        sceneDelegate.window = makeWindow()

        let scene1 = MockUIScene()
        scene1.delegate = sceneDelegate

        let sut = TestSentryUIApplication()
        sut.scenes = [scene1]

        XCTAssertEqual(sut.getWindows()?.count, 1)
    }

    func test_applicationWithScenesAndDelegateWithWindow_Unique() {
        let sceneDelegate = TestUISceneDelegate()
        sceneDelegate.window = makeWindow()
        let scene1 = MockUIScene()
        scene1.delegate = sceneDelegate

        let delegate = TestApplicationDelegate()
        delegate.window = makeWindow()

        let sut = TestSentryUIApplication()
        sut.scenes = [scene1]
        sut.appDelegate = delegate

        XCTAssertEqual(sut.getWindows()?.count, 2)
    }

    func test_applicationWithScenesAndDelegateWithWindow_Same() {
        let window = makeWindow()
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

    // MARK: - getKeyWindow

    func testGetKeyWindow_whenNoWindows_shouldReturnNil() {
        // -- Arrange --
        let sut = TestSentryUIApplication()

        // -- Act --
        let result = sut.getKeyWindow()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testGetKeyWindow_whenNoKeyWindow_shouldReturnNil() {
        // -- Arrange --
        let sut = TestSentryUIApplication()
        sut.windows = [makeWindow(), makeWindow()]

        // -- Act --
        let result = sut.getKeyWindow()

        // -- Assert --
        XCTAssertNil(result)
    }

    func testGetKeyWindow_whenKeyWindowExists_shouldReturnKeyWindow() {
        // -- Arrange --
        let sut = TestSentryUIApplication()
        let keyWindow = MockKeyUIWindow(windowScene: Self.mockWindowScene)
        sut.windows = [makeWindow(), keyWindow]

        // -- Act --
        let result = sut.getKeyWindow()

        // -- Assert --
        XCTAssertIdentical(result, keyWindow)
    }

    func testGetKeyWindow_whenMultipleKeyWindows_shouldReturnFirst() {
        // -- Arrange --
        let sut = TestSentryUIApplication()
        let firstKeyWindow = MockKeyUIWindow(windowScene: Self.mockWindowScene)
        let secondKeyWindow = MockKeyUIWindow(windowScene: Self.mockWindowScene)
        sut.windows = [makeWindow(), firstKeyWindow, secondKeyWindow]

        // -- Act --
        let result = sut.getKeyWindow()

        // -- Assert --
        XCTAssertIdentical(result, firstKeyWindow)
    }

    func testInternalRelevantViewControllers_whenWindowFilterProvided_shouldOnlyUseMatchingWindows() throws {
        // -- Arrange --
        let excludedViewController = UIViewController()
        let excludedWindow = makeWindow()
        excludedWindow.rootViewController = excludedViewController

        let includedViewController = UIViewController()
        let includedWindow = makeWindow()
        includedWindow.rootViewController = includedViewController

        let sut = TestSentryUIApplication()
        sut.windows = [excludedWindow, includedWindow]

        // -- Act --
        let viewControllers = try XCTUnwrap(sut.internal_relevantViewControllers { window in
            window === includedWindow
        })

        // -- Assert --
        XCTAssertEqual(viewControllers.count, 1)
        XCTAssertIdentical(viewControllers.first, includedViewController)
    }

    private class TestUISceneDelegate: NSObject, UIWindowSceneDelegate {
        var window: UIWindow?
    }

    private class MockKeyUIWindow: UIWindow {
        override var isKeyWindow: Bool { true }
    }
}
#endif
