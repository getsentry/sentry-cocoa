import XCTest

class SDKPerformanceBenchmarkTests: XCTestCase {
    func testCPUBenchmark() throws {
        let allowedIOSVersion = "15"
        try XCTSkipUnless(UIDevice.current.systemVersion.components(separatedBy: ".").first ?? "" == allowedIOSVersion, "Only run benchmarks on iOS \(allowedIOSVersion).")
        var isSimulator: Bool
        #if targetEnvironment(simulator)
        isSimulator = true
        #else
        isSimulator = false
        #endif
        try XCTSkipIf(isSimulator, "Only run benchmarks on real devices, not in simulators.")
        var results = [Double]()
        for _ in 0..<5 {
            let app = XCUIApplication()
            app.launchArguments.append("--io.sentry.test.benchmarking")
            app.launch()
            app.buttons["Performance scenarios"].tap()

            let startButton = app.buttons["Start test"]
            if !startButton.waitForExistence(timeout: 5.0) {
                XCTFail("Couldn't find benchmark retrieval button.")
            }
            startButton.tap()

            sleep(15) // let the CPU run with profiling enabled for a while; see PerformanceViewController.startTest and SentryBenchmarking.startBenchmarkProfile

            let stopButton = app.buttons["Stop test"]
            if !stopButton.waitForExistence(timeout: 5.0) {
                XCTFail("Couldn't find benchmark retrieval button.")
            }
            stopButton.tap()

            let textField = app.textFields["io.sentry.benchmark.value-marshaling-text-field"]
                if !textField.waitForExistence(timeout: 5.0) {
                XCTFail("Couldn't find benchmark value marshaling text field.")
                break
            }

            guard let benchmarkValueString = textField.value as? NSString else {
                XCTFail("No benchmark value received from the app.")
                break
            }
            let usagePercentage = benchmarkValueString.doubleValue

            // SentryBenchmarking.retrieveBenchmarks returns -1 if there aren't at least 2 samples to use for calculating deltas
            XCTAssert(usagePercentage > 0, "Failure to record enough CPU samples to calculate benchmark.")
            print("Percent usage: \(usagePercentage)%")
            results.append(usagePercentage)
        }
        let index = Int(ceil(0.9 * Double(results.count)))
        let p90 = results.sorted()[index >= results.count ? results.count - 1 : index]

        print("p90 overhead: \(p90)%")
        XCTAssertLessThanOrEqual(p90, 5, "Running profiling resulted in more than 5% overhead.")
    }
}
