import SentrySampleUITestShared
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
        app.launchEnvironment["--io.sentry.sdk-environment"] = "ui-tests"
        app.launchArguments.append(contentsOf: [
            "--io.sentry.wipe-data"
        ])
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
        app.launchEnvironment["--io.sentry.ui-test.test-name"] = name
        return app
    }
    
    func launchApp(args: [String] = [], env: [String: String] = [:]) {
        app.launchArguments.append(contentsOf: args)
        for (k, v) in env {
            app.launchEnvironment[k] = v
        }

        // Calling activate() and then launch() effectively launches the app twice, interfering with
        // local debugging. Only call activate if there isn't a debugger attached, which is a decent
        // proxy for whether this is running in CI.
        if !isDebugging() {
            // activate() appears to drop launch args and environment variables, so save them beforehand and reset them before subsequent calls to launch()
            let launchArguments = app.launchArguments
            let launchEnvironment = app.launchEnvironment

            // App prewarming can sometimes cause simulators to get stuck in UI tests, activating them
            // before launching clears any prewarming state.
            app.activate()

            app.launchArguments = launchArguments
            app.launchEnvironment = launchEnvironment
        }

        app.launch()

        waitForExistenceOfMainScreen()
    }
    
    func waitForExistenceOfMainScreen() {
        app.waitForExistence("Home Screen doesn't exist.")
    }
    
}
