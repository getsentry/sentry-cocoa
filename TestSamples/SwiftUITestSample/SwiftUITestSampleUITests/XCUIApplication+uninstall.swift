import XCTest

// This snipped was obtained from https://www.jessesquires.com/blog/2021/10/25/delete-app-during-ui-tests/
extension XCUIApplication {
    func uninstall(skipIfNotFound: Bool = false) {
        self.terminate()

        let timeout = TimeInterval(5)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

        let uiTestRunnerName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? ""
        let appName = uiTestRunnerName.replacingOccurrences(of: "UITests-Runner", with: "")

        /// use `firstMatch` because icon may appear in iPad dock
        let appIcon = springboard.icons[appName].firstMatch
        if appIcon.waitForExistence(timeout: timeout) {
            appIcon.press(forDuration: 2)
        } else if !skipIfNotFound {
            XCTFail("Failed to find app icon named \(appName)")
        } else {
            return
        }

        let removeAppButton = springboard.buttons["Remove App"]
        if removeAppButton.waitForExistence(timeout: timeout) {
            removeAppButton.tap()
        } else {
            XCTFail("Failed to find 'Remove App'")
        }

        let deleteAppButton = springboard.alerts.buttons["Delete App"]
        if deleteAppButton.waitForExistence(timeout: timeout) {
            deleteAppButton.tap()
        } else {
            XCTFail("Failed to find 'Delete App'")
        }

        let finalDeleteButton = springboard.alerts.buttons["Delete"]
        if finalDeleteButton.waitForExistence(timeout: timeout) {
            finalDeleteButton.tap()
        } else {
            XCTFail("Failed to find 'Delete'")
        }
    }
}
