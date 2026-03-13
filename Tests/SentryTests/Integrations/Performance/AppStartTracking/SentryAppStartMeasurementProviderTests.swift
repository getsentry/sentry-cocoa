@_spi(Private) @testable import Sentry
import XCTest

#if os(iOS) || os(tvOS) || os(visionOS)

class SentryAppStartMeasurementProviderTests: XCTestCase {

    override func tearDown() {
        super.tearDown()
        SentryAppStartMeasurementProvider.reset()
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = false
        SentrySDKInternal.setAppStartMeasurement(nil)
    }

    // MARK: - Happy Path

    func testAppStartMeasurement_whenValidUiLoadOperation_shouldReturnMeasurement() {
        // -- Arrange --
        let appStartTimestamp = Date(timeIntervalSinceReferenceDate: 0)
        let appStartDuration: TimeInterval = 0.5
        let measurement = buildAppStartMeasurement(type: .cold, appStartTimestamp: appStartTimestamp, duration: appStartDuration)
        SentrySDKInternal.setAppStartMeasurement(measurement)
        let transactionStart = appStartTimestamp.addingTimeInterval(appStartDuration)

        // -- Act --
        let result = SentryAppStartMeasurementProvider.appStartMeasurement(
            forOperation: SentrySpanOperationUiLoad,
            startTimestamp: transactionStart
        )

        // -- Assert --
        XCTAssertEqual(result, measurement)
    }

    // MARK: - Operation Check

    func testAppStartMeasurement_whenNonUiLoadOperation_shouldReturnNil() {
        // -- Arrange --
        let appStartTimestamp = Date(timeIntervalSinceReferenceDate: 0)
        let appStartDuration: TimeInterval = 0.5
        SentrySDKInternal.setAppStartMeasurement(
            buildAppStartMeasurement(type: .cold, appStartTimestamp: appStartTimestamp, duration: appStartDuration)
        )
        let transactionStart = appStartTimestamp.addingTimeInterval(appStartDuration)

        // -- Act --
        let result = SentryAppStartMeasurementProvider.appStartMeasurement(
            forOperation: "custom",
            startTimestamp: transactionStart
        )

        // -- Assert --
        XCTAssertNil(result)
    }

    // MARK: - Hybrid SDK Mode

    func testAppStartMeasurement_whenHybridSDKModeEnabled_shouldReturnNil() {
        // -- Arrange --
        let appStartTimestamp = Date(timeIntervalSinceReferenceDate: 0)
        let appStartDuration: TimeInterval = 0.5
        SentrySDKInternal.setAppStartMeasurement(
            buildAppStartMeasurement(type: .cold, appStartTimestamp: appStartTimestamp, duration: appStartDuration)
        )
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = true
        let transactionStart = appStartTimestamp.addingTimeInterval(appStartDuration)

        // -- Act --
        let result = SentryAppStartMeasurementProvider.appStartMeasurement(
            forOperation: SentrySpanOperationUiLoad,
            startTimestamp: transactionStart
        )

        // -- Assert --
        XCTAssertNil(result)
    }

    // MARK: - No Measurement Available

    func testAppStartMeasurement_whenNoMeasurementAvailable_shouldReturnNil() {
        // -- Act --
        let result = SentryAppStartMeasurementProvider.appStartMeasurement(
            forOperation: SentrySpanOperationUiLoad,
            startTimestamp: Date()
        )

        // -- Assert --
        XCTAssertNil(result)
    }

    // MARK: - Already Read

    func testAppStartMeasurement_whenAlreadyRead_shouldReturnNil() {
        // -- Arrange --
        let appStartTimestamp = Date(timeIntervalSinceReferenceDate: 0)
        let appStartDuration: TimeInterval = 0.5
        SentrySDKInternal.setAppStartMeasurement(
            buildAppStartMeasurement(type: .cold, appStartTimestamp: appStartTimestamp, duration: appStartDuration)
        )
        let transactionStart = appStartTimestamp.addingTimeInterval(appStartDuration)

        let first = SentryAppStartMeasurementProvider.appStartMeasurement(
            forOperation: SentrySpanOperationUiLoad,
            startTimestamp: transactionStart
        )
        XCTAssertNotNil(first)

        // -- Act --
        let second = SentryAppStartMeasurementProvider.appStartMeasurement(
            forOperation: SentrySpanOperationUiLoad,
            startTimestamp: transactionStart
        )

        // -- Assert --
        XCTAssertNil(second)
    }

    // MARK: - Reset

    func testReset_whenCalledAfterRead_shouldAllowReadingAgain() {
        // -- Arrange --
        let appStartTimestamp = Date(timeIntervalSinceReferenceDate: 0)
        let appStartDuration: TimeInterval = 0.5
        SentrySDKInternal.setAppStartMeasurement(
            buildAppStartMeasurement(type: .cold, appStartTimestamp: appStartTimestamp, duration: appStartDuration)
        )
        let transactionStart = appStartTimestamp.addingTimeInterval(appStartDuration)

        let first = SentryAppStartMeasurementProvider.appStartMeasurement(
            forOperation: SentrySpanOperationUiLoad,
            startTimestamp: transactionStart
        )
        XCTAssertNotNil(first)

        // -- Act --
        SentryAppStartMeasurementProvider.reset()

        // -- Assert --
        let second = SentryAppStartMeasurementProvider.appStartMeasurement(
            forOperation: SentrySpanOperationUiLoad,
            startTimestamp: transactionStart
        )
        XCTAssertNotNil(second)
    }

    // MARK: - Time Difference Validation

    func testAppStartMeasurement_whenTimeDifferenceTooLargePositive_shouldReturnNil() {
        // -- Arrange --
        // App starts at t=0, ends at t=0.5. Transaction starts at t=5.51.
        // difference = appStartEnd - transactionStart = 0.5 - 5.51 = -5.01 → exceeds -5.0 boundary
        let appStartTimestamp = Date(timeIntervalSinceReferenceDate: 0)
        let appStartDuration: TimeInterval = 0.5
        SentrySDKInternal.setAppStartMeasurement(
            buildAppStartMeasurement(type: .cold, appStartTimestamp: appStartTimestamp, duration: appStartDuration)
        )
        let transactionStart = appStartTimestamp.addingTimeInterval(appStartDuration + 5.01)

        // -- Act --
        let result = SentryAppStartMeasurementProvider.appStartMeasurement(
            forOperation: SentrySpanOperationUiLoad,
            startTimestamp: transactionStart
        )

        // -- Assert --
        XCTAssertNil(result)
    }

    func testAppStartMeasurement_whenTimeDifferenceTooLargeNegative_shouldReturnNil() {
        // -- Arrange --
        // App starts at t=0, ends at t=0.5. Transaction starts at t=-4.51.
        // difference = appStartEnd - transactionStart = 0.5 - (-4.51) = 5.01 → exceeds +5.0 boundary
        let appStartTimestamp = Date(timeIntervalSinceReferenceDate: 0)
        let appStartDuration: TimeInterval = 0.5
        SentrySDKInternal.setAppStartMeasurement(
            buildAppStartMeasurement(type: .cold, appStartTimestamp: appStartTimestamp, duration: appStartDuration)
        )
        let transactionStart = appStartTimestamp.addingTimeInterval(appStartDuration - 5.01)

        // -- Act --
        let result = SentryAppStartMeasurementProvider.appStartMeasurement(
            forOperation: SentrySpanOperationUiLoad,
            startTimestamp: transactionStart
        )

        // -- Assert --
        XCTAssertNil(result)
    }

    func testAppStartMeasurement_whenTimeDifferenceExactlyAtPositiveBoundary_shouldReturnMeasurement() {
        // -- Arrange --
        // App starts at t=0, ends at t=0.5. Transaction starts at t=5.5.
        // difference = appStartEnd - transactionStart = 0.5 - 5.5 = -5.0 → exactly at boundary, not exceeding
        let appStartTimestamp = Date(timeIntervalSinceReferenceDate: 0)
        let appStartDuration: TimeInterval = 0.5
        let measurement = buildAppStartMeasurement(type: .cold, appStartTimestamp: appStartTimestamp, duration: appStartDuration)
        SentrySDKInternal.setAppStartMeasurement(measurement)
        let transactionStart = appStartTimestamp.addingTimeInterval(appStartDuration + 5.0)

        // -- Act --
        let result = SentryAppStartMeasurementProvider.appStartMeasurement(
            forOperation: SentrySpanOperationUiLoad,
            startTimestamp: transactionStart
        )

        // -- Assert --
        XCTAssertEqual(result, measurement)
    }

    func testAppStartMeasurement_whenTimeDifferenceExactlyAtNegativeBoundary_shouldReturnMeasurement() {
        // -- Arrange --
        // App starts at t=0, ends at t=0.5. Transaction starts at t=-4.5.
        // difference = appStartEnd - transactionStart = 0.5 - (-4.5) = 5.0 → exactly at boundary, not exceeding
        let appStartTimestamp = Date(timeIntervalSinceReferenceDate: 0)
        let appStartDuration: TimeInterval = 0.5
        let measurement = buildAppStartMeasurement(type: .cold, appStartTimestamp: appStartTimestamp, duration: appStartDuration)
        SentrySDKInternal.setAppStartMeasurement(measurement)
        let transactionStart = appStartTimestamp.addingTimeInterval(appStartDuration - 5.0)

        // -- Act --
        let result = SentryAppStartMeasurementProvider.appStartMeasurement(
            forOperation: SentrySpanOperationUiLoad,
            startTimestamp: transactionStart
        )

        // -- Assert --
        XCTAssertEqual(result, measurement)
    }

    func testAppStartMeasurement_whenTimeDifferenceJustWithinBoundary_shouldReturnMeasurement() {
        // -- Arrange --
        // App starts at t=0, ends at t=0.5. Transaction starts at t=5.49.
        // difference = appStartEnd - transactionStart = 0.5 - 5.49 = -4.99 → within ±5.0
        let appStartTimestamp = Date(timeIntervalSinceReferenceDate: 0)
        let appStartDuration: TimeInterval = 0.5
        let measurement = buildAppStartMeasurement(type: .cold, appStartTimestamp: appStartTimestamp, duration: appStartDuration)
        SentrySDKInternal.setAppStartMeasurement(measurement)
        let transactionStart = appStartTimestamp.addingTimeInterval(appStartDuration + 4.99)

        // -- Act --
        let result = SentryAppStartMeasurementProvider.appStartMeasurement(
            forOperation: SentrySpanOperationUiLoad,
            startTimestamp: transactionStart
        )

        // -- Assert --
        XCTAssertEqual(result, measurement)
    }

    // MARK: - Concurrency

    func testAppStartMeasurement_whenCalledConcurrently_shouldReturnMeasurementOnlyOnce() {
        // -- Arrange --
        let appStartTimestamp = Date(timeIntervalSinceReferenceDate: 0)
        let appStartDuration: TimeInterval = 0.5
        SentrySDKInternal.setAppStartMeasurement(
            buildAppStartMeasurement(type: .cold, appStartTimestamp: appStartTimestamp, duration: appStartDuration)
        )
        let transactionStart = appStartTimestamp.addingTimeInterval(appStartDuration)

        let queue = DispatchQueue(label: "testConcurrentAccess", attributes: [.concurrent, .initiallyInactive])
        let count = 10
        let expectation = XCTestExpectation(description: "All calls complete")
        expectation.expectedFulfillmentCount = count

        var results = [SentryAppStartMeasurement?]()
        let resultsLock = NSLock()

        // -- Act --
        for _ in 0..<count {
            queue.async(execute: DispatchWorkItem {
                let result = SentryAppStartMeasurementProvider.appStartMeasurement(
                    forOperation: SentrySpanOperationUiLoad,
                    startTimestamp: transactionStart
                )
                resultsLock.lock()
                results.append(result)
                resultsLock.unlock()
                expectation.fulfill()
            })
        }
        queue.activate()
        wait(for: [expectation], timeout: 10.0)

        // -- Assert --
        let nonNilResults = results.compactMap { $0 }
        XCTAssertEqual(nonNilResults.count, 1, "Expected exactly one non-nil result from concurrent calls, got \(nonNilResults.count)")
    }

    // MARK: - Helpers

    private func buildAppStartMeasurement(type: SentryAppStartType, appStartTimestamp: Date, duration: TimeInterval) -> SentryAppStartMeasurement {
        return SentryAppStartMeasurement(
            type: type,
            isPreWarmed: false,
            appStartTimestamp: appStartTimestamp,
            runtimeInitSystemTimestamp: 0,
            duration: duration,
            runtimeInitTimestamp: appStartTimestamp.addingTimeInterval(0.05),
            moduleInitializationTimestamp: appStartTimestamp.addingTimeInterval(0.15),
            sdkStartTimestamp: appStartTimestamp.addingTimeInterval(0.1),
            didFinishLaunchingTimestamp: appStartTimestamp.addingTimeInterval(0.2)
        )
    }
}

#endif // os(iOS) || os(tvOS) || os(visionOS)
