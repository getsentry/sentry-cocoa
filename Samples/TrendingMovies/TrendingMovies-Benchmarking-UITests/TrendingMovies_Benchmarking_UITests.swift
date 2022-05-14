import XCTest

class TrendingMovies_Benchmarking_UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBenchmarkingOnScrolling() throws {
        var avgPercentIncrease = 0.0
        for _ in 0..<5 {
            let app = XCUIApplication()
            guard let withoutProfiling = benchmarkAppUsage(app: app, withProfiling: false) else { return }
            app.terminate()
            guard let withProfiling = benchmarkAppUsage(app: app, withProfiling: true) else { return }
            avgPercentIncrease += Double(withProfiling - withoutProfiling) / Double(withoutProfiling)
        }
        avgPercentIncrease /= 5.0
        print("Average overhead: \(avgPercentIncrease * 100)%")
        XCTAssertLessThanOrEqual(avgPercentIncrease, 0.05, "Running profiling resulted in more than 5% overhead while scrolling in the app.")
    }
}

extension TrendingMovies_Benchmarking_UITests {
    func benchmarkAppUsage(app: XCUIApplication, withProfiling: Bool) -> Int64? {
        app.launchArguments.append("--io.sentry.ui-test.benchmarking")
        if withProfiling {
            app.launchArguments.append("--io.sentry.enable-profiling")
        }
        app.launch()

        startBenchmark(app: app)

        for _ in 0..<5 {
            app.swipeUp(velocity: .fast)
        }

        return stopBenchmark(app: app)
    }

    func startBenchmark(app: XCUIApplication) {
        tapBenchmarkStartStopButton(app: app)
    }

    func stopBenchmark(app: XCUIApplication) -> Int64? {
        tapBenchmarkStartStopButton(app: app)

        let textField = app.textFields["io.sentry.accessibility-identifier.benchmarking-value-marshaling-text-field"]
            if !textField.waitForExistence(timeout: 5.0) {
            XCTFail("Couldn't find benchmark value marshaling text field.")
            return nil
        }

        guard let benchmarkValueString = textField.value as? NSString else {
            XCTFail("No benchmark value received from the app.")
            return nil
        }

        return benchmarkValueString.longLongValue
    }

    func tapBenchmarkStartStopButton(app: XCUIApplication) {
        let button = app.buttons["io.sentry.accessibility-identifier.benchmarking-value-marshaling-button"]
        if !button.waitForExistence(timeout: 5.0) {
            XCTFail("Couldn't find benchmark retrieval button.")
        }
        button.tap()
    }
}
