import XCTest

class LaunchUITests: XCTestCase {
    private let app: XCUIApplication = XCUIApplication()

    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        
        waitForExistenceOfMainScreen()
        checkSlowAndFrozenFrames()
    }
    
    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func testCrashRecovery() {
        //We will be removing this test from iOS 12 because it fails during CI, which looks like a bug that we cannot reproduce.
        //If we introduce a bug in the crash report process we will catch it with tests for iOS 13 or above.
        //For some reason is not possible to use @available(iOS 13, *) in the test function.
        if #available(iOS 13, *) {
            app.buttons["crash"].tap()
            if app.buttons["crash"].exists {
                XCTFail("App did not crashed")
            }

            app.launch()
            waitForExistenceOfMainScreen()
        }
    }

    func testBreadcrumbData() {
        let breadcrumbLabel = app.staticTexts["breadcrumbLabel"]
        breadcrumbLabel.waitForExistence("Breadcrumb label not found.")
        XCTAssertEqual(breadcrumbLabel.label, "{ category: ui.lifecycle, parentViewController: UINavigationController, beingPresented: false, window_isKeyWindow: true, is_window_rootViewController: false }")
    }

    func testLoremIpsum() {
        app.buttons["loremIpsumButton"].tap()
        app.textViews.firstMatch.waitForExistence("Lorem Ipsum not loaded.")
    }
    
    func testNavigationTransaction() {
        app.buttons["testNavigationTransactionButton"].tap()
        app.images.firstMatch.waitForExistence("Navigation transaction not loaded.")
        assertApp()
    }
    
    func testShowNib() {
        app.buttons["showNibButton"].tap()
        app.buttons["lonelyButton"].waitForExistence("Nib ViewController not loaded.")
        assertApp()
    }
    
    func testUiClickTransaction() {
        app.buttons["uiClickTransactionButton"].tap()
    }
    
    func testCaptureError() {
        app.buttons["Error"].tap()
    }
    
    func testCaptureException() {
        app.buttons["NSException"].tap()
    }
    
    func testShowTableView() {
        app.buttons["showTableViewButton"].tap()
        app.navigationBars.buttons.element(boundBy: 0).waitForExistence("TableView not loaded.")
        assertApp()
    }
    
    func testSplitView() {
        app.buttons["showSplitViewButton"].tap()
        
        let app = XCUIApplication()
        app.navigationBars["iOS_Swift.SecondarySplitView"].buttons["Root ViewController"].waitForExistence("SplitView not loaded.")
        
        // This validation is currently not working on iOS 12 and iOS 10.
        if #available(iOS 13.0, *) {
            assertApp()
        }
    }

    /**
     * We had a bug where we forgot to install the frames tracker into the profiler, so weren't sending any GPU frame information with profiles. Since it's not possible to enforce such installation via the compiler, we test for the results we expect here, by starting a transaction, triggering an ANR which will cause degraded frame rendering, stop the transaction, and inspect the profile payload.
     */
    func testProfilingGPUInfo() throws {
        app.buttons["Start transaction"].afterWaitingForExistence("Couldn't find button to start transaction").tap()
        app.buttons["ANR filling run loop"].afterWaitingForExistence("Couldn't find button to ANR").tap()
        app.buttons["Stop transaction"].afterWaitingForExistence("Couldn't find button to end transaction").tap()

        let textField = app.textFields["io.sentry.ui-tests.profile-marshaling-text-field"]
        textField.waitForExistence("Couldn't find profile marshaling text field.")

        let profileBase64DataString = try XCTUnwrap(textField.value as? NSString)
        let profileData = try XCTUnwrap(Data(base64Encoded: profileBase64DataString as String))
        let profileDict = try XCTUnwrap(try JSONSerialization.jsonObject(with: profileData) as? [String: Any])

        let metrics = try XCTUnwrap(profileDict["measurements"] as? [String: Any])
        let slowFrames = try XCTUnwrap(metrics["slow_frame_renders"] as? [String: Any])
        let slowFrameValues = try XCTUnwrap(slowFrames["values"] as? [[String: Any]])
        let frozenFrames = try XCTUnwrap(metrics["frozen_frame_renders"] as? [String: Any])
        let frozenFrameValues = try XCTUnwrap(frozenFrames["values"] as? [[String: Any]])
        XCTAssertFalse(slowFrameValues.isEmpty && frozenFrameValues.isEmpty)

        let frameRates = try XCTUnwrap(metrics["screen_frame_rates"] as? [String: Any])
        let frameRateValues = try XCTUnwrap(frozenFrames["values"] as? [[String: Any]])
        XCTAssertFalse(frameRateValues.isEmpty)
    }
}

private extension LaunchUITests {
    func waitForExistenceOfMainScreen() {
        app.buttons["captureMessageButton"].waitForExistence( "Home Screen doesn't exist.")
    }
    
    func checkSlowAndFrozenFrames() {
        let frameStatsLabel = app.staticTexts["framesStatsLabel"]
        frameStatsLabel.waitForExistence("Frame statistics message not found.")
        
        let frameStatsAsStringArray = frameStatsLabel.label.components(separatedBy: CharacterSet.decimalDigits.inverted)
        let frameStats = frameStatsAsStringArray.filter { $0 != "" }.map { Int($0) }
        
        XCTAssertEqual(3, frameStats.count)
        guard let totalFrames = frameStats[0] else { XCTFail("No total frames found."); return }
        guard let slowFrames = frameStats[1] else { XCTFail("No slow frames found."); return }
        guard let frozenFrames = frameStats[1] else { XCTFail("No frozen frames found."); return }

        let slowFramesPercentage = Double(slowFrames) / Double(totalFrames)
        XCTAssertTrue(0.5 > slowFramesPercentage, "Too many slow frames.")
        
        let frozenFramesPercentage = Double(frozenFrames) / Double(totalFrames)
        XCTAssertTrue(0.5 > frozenFramesPercentage, "Too many frozen frames.")
    }
    
    func assertApp() {
        let confirmation = app.staticTexts["ASSERT_MESSAGE"]
        let errorMessage = app.staticTexts["ASSERT_ERROR"]
        confirmation.waitForExistence("Assertion Message Not Found")
        
        XCTAssertTrue(confirmation.label == "ASSERT: SUCCESS", errorMessage.label)
    }
}

extension XCUIElement {
    func waitForExistence(_ message: String) {
        XCTAssertTrue(self.waitForExistence(timeout: TimeInterval(10)), message)
    }

    func afterWaitingForExistence(_ failureMessage: String) -> XCUIElement {
        waitForExistence(failureMessage)
        return self
    }
}
