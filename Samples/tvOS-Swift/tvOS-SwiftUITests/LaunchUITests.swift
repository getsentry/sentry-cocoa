import Sentry
import XCTest

class LaunchUITests: XCTestCase {
    
    private let app: XCUIApplication = XCUIApplication()

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        
        app.launch()
    }
    
    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    func testLaunch() throws {
        waitForExistenseOfMainScreen()
    }
    
    func testAppStart() {
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable = { appStartMeasurement in
            let appStart = try! XCTUnwrap(appStartMeasurement)
            XCTAssertTrue(appStart.appStartTimestamp < appStart.mainTimestamp)
            XCTAssertTrue(appStart.mainTimestamp < appStart.runtimeInitTimestamp)
            XCTAssertTrue(appStart.runtimeInitTimestamp < appStart.didFinishLaunchingTimestamp)
            
            XCTAssertTrue(appStart.duration < 30)
        }
    }
    
    private func waitForExistenseOfMainScreen() {
        XCTAssertTrue(app.buttons["captureMessageButton"].waitForExistence(), "Home Screen doesn't exist.")
    }
}

extension XCUIElement {

    @discardableResult
    func waitForExistence() -> Bool {
        self.waitForExistence(timeout: TimeInterval(10))
    }
}
