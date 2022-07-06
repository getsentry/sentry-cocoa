import XCTest
import ObjectiveC

class SDKPerformanceBenchmarkTests: XCTestCase {

    func _testCPUBenchmark() throws -> [Double] {

        var results = [Double]()
        for _ in 0..<1/*5*/ {
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
            results.append(usagePercentage)
        }

        return results
    }
}
