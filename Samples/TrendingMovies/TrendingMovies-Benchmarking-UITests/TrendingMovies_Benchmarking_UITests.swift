import XCTest

class TrendingMovies_Benchmarking_UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {

    }

    func testExample() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--io.sentry.ui-test.benchmarking")
        app.launch()
    }
}
