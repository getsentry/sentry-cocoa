import XCTest

class TrendingMoviesBenchmarkingUITests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    func testBenchmarkingOnScrolling() throws {
        var avgUsagePercentage = 0.0
        let numberOfTrials = 15
        for _ in 0..<numberOfTrials {
            let app = XCUIApplication()
            guard let usagePercentage = benchmarkAppUsage(app: app, withProfiling: true) else { return }
            print("Percent usage: \(usagePercentage)%")
            avgUsagePercentage += usagePercentage
        }
        avgUsagePercentage /= Double(numberOfTrials)

        guard let path = String(describing: #file).components(separatedBy: "Samples").first else {
            XCTFail("Could not find location to write benchmark report.")
            return
        }
        let url = URL(fileURLWithPath: path).appendingPathComponent("benchmark.json")
        try JSONEncoder().encode(["profiling_overhead_percentage": avgUsagePercentage]).write(to: url)

        print("Average overhead: \(avgUsagePercentage)%")
        XCTAssertLessThanOrEqual(avgUsagePercentage, 5, "Running profiling resulted in more than 5% overhead while scrolling in the app.")
    }
}

extension TrendingMoviesBenchmarkingUITests {
    func benchmarkAppUsage(app: XCUIApplication, withProfiling: Bool) -> Double? {
        app.launchArguments.append("--io.sentry.ui-test.benchmarking")
        if withProfiling {
            app.launchArguments.append("--io.sentry.enable-profiling")
        }
        app.launch()

        func performBenchmarkedWork(app: XCUIApplication) -> Double? {
            startBenchmark(app: app)
            for _ in 0..<5 {
                app.swipeUp(velocity: .fast)
            }
            return stopBenchmark(app: app)
        }

        // warm up caches by performing the operation we'll benchmark, plus running the profiling components
        for _ in 0..<3 {
            let _ = performBenchmarkedWork(app: app)
        }

        return performBenchmarkedWork(app: app)
    }

    func startBenchmark(app: XCUIApplication) {
        tapBenchmarkStartStopButton(app: app)
    }

    func stopBenchmark(app: XCUIApplication) -> Double? {
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

        return benchmarkValueString.doubleValue
    }

    func tapBenchmarkStartStopButton(app: XCUIApplication) {
        let button = app.buttons["io.sentry.accessibility-identifier.benchmarking-value-marshaling-button"]
        if !button.waitForExistence(timeout: 5.0) {
            XCTFail("Couldn't find benchmark retrieval button.")
        }
        button.tap()
    }
}
