import XCTest

class TrendingMovies_Benchmarking_UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBenchmarkingOnLaunch() throws {
        guard let withoutProfiling = measureAppLaunch(withProfiling: false) else { return }
        XCUIApplication().terminate()
        guard let withProfiling = measureAppLaunch(withProfiling: true) else { return }
        XCTAssertLessThanOrEqual((withProfiling - withoutProfiling) / withoutProfiling, 0.05, "Running profiling resulted in more than 5% overhead on app launch.")
    }

    func testBenchmarkingOnScrolling() throws {
        guard let withoutProfiling = measureScrollingInApp(withProfiling: false) else { return }
        XCUIApplication().terminate()
        guard let withProfiling = measureScrollingInApp(withProfiling: true) else { return }
        XCTAssertLessThanOrEqual((withProfiling - withoutProfiling) / withoutProfiling, 0.05, "Running profiling resulted in more than 5% overhead while scrolling in the app.")
    }
}

extension TrendingMovies_Benchmarking_UITests {
    func measureAppLaunch(withProfiling: Bool) -> Double? {
        launchApp(withProfiling: withProfiling, launchOnly: true)
        return getValue()
    }

    func measureScrollingInApp(withProfiling: Bool) -> Double? {
        launchApp(withProfiling: withProfiling, launchOnly: false)

        let app = XCUIApplication()
        for _ in 0..<25 {
            app.swipeDown(velocity: .fast)
        }

        return getValue()
    }

    func launchApp(withProfiling: Bool, launchOnly: Bool) {
        let app = XCUIApplication()
        app.launchArguments.append("--io.sentry.ui-test.benchmarking")
        app.launchArguments.append(launchOnly ? "--io.sentry.ui-test.benchmark-launch" : "--io.sentry.ui-test.benchmark-app-usage")
        if withProfiling {
            app.launchArguments.append("--io.sentry.enable-profiling")
        }
        app.launch()
    }

    func getValue() -> Double? {
        let app = XCUIApplication()
        let textField = app.textFields["io.sentry.accessibility-identifier.benchmarking-value-marshaling-text-field"]
        if !textField.waitForExistence(timeout: 5.0) {
            XCTFail("Couldn't find benchmark value marshaling text field.")
            return nil
        }

        guard let benchmarkValueString = textField.value as? NSString else {
            XCTFail("No benchmark value received from the app.")
            return nil
        }

        return benchmarkValueString.doubleValue
    }
}
