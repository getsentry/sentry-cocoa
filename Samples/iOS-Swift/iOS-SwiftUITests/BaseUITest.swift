import XCTest

class BaseUITest: XCTestCase {
    internal lazy var app: XCUIApplication = newAppSession()
    
    //swiftlint:disable implicit_getter
    var automaticallyLaunchAndTerminateApp: Bool { get { true } }
    //swiftlint:enable implicit_getter
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app.launchEnvironment["io.sentry.sdk-environment"] = "ui-tests"
        if automaticallyLaunchAndTerminateApp {
            launchApp()
        }
    }
    
    override func tearDown() {
        if automaticallyLaunchAndTerminateApp {
            app.terminate()
        }
        super.tearDown()
    }
}

extension BaseUITest {
    func newAppSession() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["io.sentry.ui-test.test-name"] = name
        return app
    }
    
    func launchApp() {
        app.launch()
        waitForExistenceOfMainScreen()
    }
    
    func waitForExistenceOfMainScreen() {
        app.waitForExistence("Home Screen doesn't exist.")
    }
    
}
