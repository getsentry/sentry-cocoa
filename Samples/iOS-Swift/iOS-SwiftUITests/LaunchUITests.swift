import XCTest

class LaunchUITests: BaseUITest {

    func testCrashRecovery() {
        //We will be removing this test from iOS 12 because it fails during CI, which looks like a bug that we cannot reproduce.
        //If we introduce a bug in the crash report process we will catch it with tests for iOS 13 or above.
        //For some reason is not possible to use @available(iOS 13, *) in the test function.
        if #available(iOS 13, *) {
            app.buttons["Crash the app"].tap()
            if app.buttons["Crash the app"].exists {
                XCTFail("App did not crashed")
            }

            app.launch()
            waitForExistenceOfMainScreen()
        }
    }

    func testBreadcrumbData() {
        app.buttons["Extra"].tap()

        let breadcrumbLabel = app.staticTexts["breadcrumbLabel"]
        breadcrumbLabel.waitForExistence("Breadcrumb label not found.")
        XCTAssertEqual(breadcrumbLabel.label, "{ category: ui.lifecycle, parentViewController: UITabBarController, beingPresented: false, window_isKeyWindow: true, is_window_rootViewController: false }")
    }

    func testLoremIpsum() {
        app.buttons["Transactions"].tap()
        app.buttons["loremIpsumButton"].tap()
        app.textViews.firstMatch.waitForExistence("Lorem Ipsum not loaded.")
    }
    
    func testNavigationTransaction() {
        app.buttons["Transactions"].tap()
        app.buttons["testNavigationTransactionButton"].tap()
        app.images.firstMatch.waitForExistence("Navigation transaction not loaded.")
        assertApp()
    }
    
    func testShowNib() {
        app.buttons["Transactions"].tap()
        app.buttons["showNibButton"].tap()
        app.buttons["lonelyButton"].waitForExistence("Nib ViewController not loaded.")
        assertApp()
    }
    
    func testUiClickTransaction() {
        app.buttons["Transactions"].tap()
        app.buttons["uiClickTransactionButton"].tap()
    }
    
    func testCaptureError() {
        app.buttons["Capture Error"].tap()
    }
    
    func testCaptureException() {
        app.buttons["Capture NSException"].tap()
    }
    
    func testShowTableView() {
        app.buttons["Transactions"].tap()
        app.buttons["showTableViewButton"].tap()
        app.navigationBars.buttons.element(boundBy: 0).waitForExistence("TableView not loaded.")
        assertApp()
    }
    
    func testSplitView() {
        app.buttons["Transactions"].tap()
        app.buttons["showSplitViewButton"].tap()
        
        let app = XCUIApplication()
        app.navigationBars["iOS_Swift.SecondarySplitView"].buttons["Root ViewController"].waitForExistence("SplitView not loaded.")
        
        // This validation is currently not working on iOS 12 and iOS 10.
        if #available(iOS 13.0, *) {
            assertApp()
        }
    }

    func testCheckSlowAndFrozenFrames() {
        app.buttons["Extra"].tap()
        checkSlowAndFrozenFrames()
    }

    /**
     * We received a customer report that ASAN reports a use-after-free error after
     * calling UIImage(named:) with an empty string argument. Recording another
     * transaction leads to the ASAN error.
     */
    func testUseAfterFreeAfterUIImageNamedEmptyString() throws {
        guard #available(iOS 14, *) else {
            throw XCTSkip("Only run for iOS 14 or later")
        }

        let app = XCUIApplication()

        // this primes the state required according to the customer report, by setting a UIImageView.image property to a UIImage(named: "")
        app/*@START_MENU_TOKEN@*/.staticTexts["Use-after-free"]/*[[".buttons[\"Use-after-free\"].staticTexts[\"Use-after-free\"]",".staticTexts[\"Use-after-free\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()

        // this causes another transaction to be recorded which hits the codepath necessary for the ASAN to trip
        app.tabBars["Tab Bar"].buttons["Extra"].tap()
    }
}

private extension LaunchUITests {
    
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
