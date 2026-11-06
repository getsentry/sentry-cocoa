import XCTest

/// GH-9536: with UIViewController tracing enabled, adding many child view controllers in one run
/// loop turn blocks the main thread for seconds, because span finishing and `SentryWeakMap` pruning
/// grow with N². See ``ManyChildViewControllersViewController``.
///
/// Both tests add the same number of children and assert the main thread stays below the app hang
/// threshold. The first test uses the default configuration and fails while the bug is present.
/// The second applies the `swizzleClassNameExcludes` workaround for the child class.
class ManyChildViewControllersUITests: BaseUITest {
    override var automaticallyLaunchAndTerminateApp: Bool { false }

    /// The reporter's device hung at ~1,200 children; simulators are faster, so use more.
    private let childCount = 5_000
    /// The SDK's default `appHangTimeoutInterval`.
    private let maxBlockedSeconds = 2.0

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func testAddManyChildViewControllers_whenTracingEnabled_shouldNotBlockMainThread() throws {
        // -- Arrange --
        launchApp(env: [
            "--io.sentry.ui-test.many-child-view-controllers-count": "\(childCount)"
        ])

        // -- Act --
        let blockedSeconds = try addChildViewControllers()

        // -- Assert --
        XCTAssertLessThan(
            blockedSeconds, maxBlockedSeconds,
            "Adding \(childCount) child view controllers blocked the main thread for \(blockedSeconds) s."
        )
    }

    func testAddManyChildViewControllers_whenChildClassExcludedFromSwizzling_shouldNotBlockMainThread() throws {
        // -- Arrange --
        launchApp(env: [
            "--io.sentry.ui-test.many-child-view-controllers-count": "\(childCount)",
            "--io.sentry.ui-test.swizzle-class-name-excludes": "ManyChildViewControllersChildViewController"
        ])

        // -- Act --
        let blockedSeconds = try addChildViewControllers()

        // -- Assert --
        XCTAssertLessThan(
            blockedSeconds, maxBlockedSeconds,
            "Adding \(childCount) excluded child view controllers blocked the main thread for \(blockedSeconds) s."
        )
    }

    /// Opens the screen, adds the children, and returns how long the main thread was blocked.
    private func addChildViewControllers() throws -> Double {
        app.tabBars.buttons["Extra"].tap()

        let openButton = app.buttons["Many child VCs #9536"]
        openButton.waitForExistence("Many child VCs button not found in Extra tab.")
        openButton.tap()

        let addButton = app.buttons["manyChildViewControllersAdd"]
        addButton.waitForExistence("Add button not found on the many child VCs screen.")
        addButton.tap()

        // The label is set on the first frame after the burst, so wait for the freeze to end.
        let blockedSecondsLabel = app.staticTexts["manyChildViewControllersBlockedSeconds"]
        blockedSecondsLabel.waitForExistence("Result label not found on the many child VCs screen.")
        let hasResult = NSPredicate(format: "label != 'pending'")
        let expectation = XCTNSPredicateExpectation(predicate: hasResult, object: blockedSecondsLabel)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 120), .completed, "No result after adding child view controllers.")

        let blockedSeconds = try XCTUnwrap(Double(blockedSecondsLabel.label), "Unexpected result: \(blockedSecondsLabel.label)")
        print("[GH-9536] \(name): main thread blocked for \(blockedSeconds) s with \(childCount) children")
        return blockedSeconds
    }
}
