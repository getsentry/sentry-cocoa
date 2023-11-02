import XCTest

class BaseUITest: XCTestCase {
    internal let app: XCUIApplication = XCUIApplication()
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchEnvironment["io.sentry.ui-test.test-name"] = name
        app.launch()
        
        waitForExistenceOfMainScreen()
    }
    
    override func tearDown() {
        app.terminate()
        super.tearDown()
    }
    
    func waitForExistenceOfMainScreen() {
        app.waitForExistence( "Home Screen doesn't exist.")
    }
    
}
