import XCTest

class SDKPerformanceBenchmarkTests: XCTestCase {
    func testCPUBenchmark() throws {
        try XCTSkipUnless(UIDevice.current.systemVersion.components(separatedBy: ".").first ?? "" == "15", "Only run benchmarks on iOS 15.")
        var avgUsagePercentage = 0.0
        let numberOfTrials = 5
        for _ in 0..<numberOfTrials {
            let app = XCUIApplication()
            guard let usagePercentage = benchmarkAppUsage(app: app, withProfiling: true) else { return }
            XCTAssert(usagePercentage > 0, "Failure to record enough CPU samples to calculate benchmark.")
            print("Percent usage: \(usagePercentage)%")
            avgUsagePercentage += usagePercentage
        }
        avgUsagePercentage /= Double(numberOfTrials)

        print("Average overhead: \(avgUsagePercentage)%")
        XCTAssertLessThanOrEqual(avgUsagePercentage, 5, "Running profiling resulted in more than 5% overhead while scrolling in the app.")
    }
}

extension SDKPerformanceBenchmarkTests {
    func benchmarkAppUsage(app: XCUIApplication, withProfiling: Bool) -> Double? {
        app.launchArguments.append("--io.sentry.ui-test.benchmarking")
        if withProfiling {
            app.launchArguments.append("--io.sentry.enable-profiling")
        }
        app.launch()
        app.buttons["Performance scenarios"].tap()

        func performBenchmarkedWork(app: XCUIApplication) -> Double? {
            startBenchmark(app: app)
            sleep(15) // let the CPU run with profiling enabled for a while; see PerformanceViewController.startTest and SentryBenchmarking.startBenchmarkProfile
            return stopBenchmark(app: app)
        }

        return performBenchmarkedWork(app: app)
    }

    func startBenchmark(app: XCUIApplication) {
        let button = app.buttons["Start test"]
        if !button.waitForExistence(timeout: 5.0) {
            XCTFail("Couldn't find benchmark retrieval button.")
        }
        button.tap()
    }

    func stopBenchmark(app: XCUIApplication) -> Double? {
        let button = app.buttons["Stop test"]
        if !button.waitForExistence(timeout: 5.0) {
            XCTFail("Couldn't find benchmark retrieval button.")
        }
        button.tap()

        let textField = app.textFields["io.sentry.benchmark.value-marshaling-text-field"]
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
