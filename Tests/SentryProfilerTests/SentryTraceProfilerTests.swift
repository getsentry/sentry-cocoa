import _SentryPrivate
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
class SentryTraceProfilerTests: XCTestCase {

    private var fixture: SentryProfileTestFixture!

    override class func setUp() {
        super.setUp()
        SentryLog.configure(true, diagnosticLevel: .debug)
    }

    override func setUp() {
        super.setUp()
        fixture = SentryProfileTestFixture()
    }

    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testMetricProfiler() throws {
        let span = try fixture.newTransaction()
        try addMockSamples()
        try fixture.gatherMockedTraceProfileMetrics()
        self.fixture.currentDateProvider.advanceBy(nanoseconds: 1.toNanoSeconds())
        span.finish()
        try self.assertMetricsPayload()
    }

    func testTransactionWithMutatedTracerID() throws {
        let span = try fixture.newTransaction()
        try addMockSamples()
        self.fixture.currentDateProvider.advanceBy(nanoseconds: 1.toNanoSeconds())
        span.traceId = SentryId()
        span.finish()
        try self.assertValidTraceProfileData()
    }

    func testConcurrentProfilingTransactions() throws {
        let numberOfTransactions = 10
        var spans = [Span]()

        func createConcurrentSpansWithMetrics() throws {
            XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
            XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))

            for i in 0 ..< numberOfTransactions {
                print("creating new concurrent transaction for test")
                let span = try fixture.newTransaction()

                // because energy readings are computed as the difference between sequential cumulative readings, we must increment the mock value by the expected result each iteration
                fixture.systemWrapper.overrides.cpuEnergyUsage = NSNumber(value: try XCTUnwrap(fixture.systemWrapper.overrides.cpuEnergyUsage).intValue + fixture.mockMetrics.cpuEnergyUsage.intValue)

                XCTAssertTrue(SentryTraceProfiler.isCurrentlyProfiling())
                XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(i + 1))
                spans.append(span)
                fixture.currentDateProvider.advanceBy(nanoseconds: 100)
            }

            let threadMetadata = SentryProfileTestFixture.ThreadMetadata(id: 1, priority: 2, name: "test-thread")
            try addMockSamples(threadMetadata: threadMetadata)

            for (i, span) in spans.enumerated() {
                try fixture.gatherMockedTraceProfileMetrics()
                
                XCTAssertTrue(SentryTraceProfiler.isCurrentlyProfiling())
                span.finish()
                XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(numberOfTransactions - (i + 1)))

                try self.assertValidTraceProfileData(expectedThreadMetadata: [threadMetadata])

                // this is a complicated number to come up with, see the explanation for each part...
                let expectedUsageReadings = fixture.mockMetrics.readingsPerBatch * (i + 1) // since we fire mock metrics readings for each concurrent span,
                                                                                        // we need to accumulate across the number of spans each iteration
                    + numberOfTransactions // and then, add the number of spans that were created to account for the start reading for each span
                    + 1 // and the end reading for this span
                try self.assertMetricsPayload(oneLessEnergyReading: i == 0, expectedMetricsReadingsPerBatchOverride: expectedUsageReadings)
            }
            
            XCTAssertFalse(SentryTraceProfiler.isCurrentlyProfiling())
            XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        }

        try createConcurrentSpansWithMetrics()

        // do everything again to make sure that stopping and starting the profiler over again works
        spans.removeAll()
#if !os(macOS)
        fixture.resetProfileGPUExpectations()
#endif // !os(macOS)

        try createConcurrentSpansWithMetrics()
    }

    /// Test a situation where a long-running span starts the profiler, which winds up timing out, and then another span starts that begins a new profile, then finishes, and then the long-running span finishes; both profiles should be separately captured in envelopes.
    /// ```
    ///                        time->
    ///    transaction A       |---------------------------------------------------|
    ///    profiler A          |---------------------------x  <- timeout
    ///    transaction B                                           |-------|
    ///    profiler B                                              |-------|  <- normal finish
    ///   ```
    func testConcurrentSpansWithTimeout() throws {
        // start span A and mock profile data for it
        let spanA = try fixture.newTransaction()
        fixture.currentDateProvider.advanceBy(nanoseconds: 1.toNanoSeconds())
        let expectedAddressesA: [NSNumber] = [0x1, 0x2, 0x3]
        let expectedThreadMetadataA = SentryProfileTestFixture.ThreadMetadata(id: 1, priority: 2, name: "test-thread1")
        try addMockSamples(threadMetadata: expectedThreadMetadataA, addresses: expectedAddressesA)

        // time out profiler for span A
        fixture.currentDateProvider.advanceBy(nanoseconds: 30.toNanoSeconds())
        fixture.timeoutTimerFactory.fire()

        fixture.currentDateProvider.advanceBy(nanoseconds: 0.5.toNanoSeconds())

        // start span B and mock profile data for it
        let spanB = try fixture.newTransaction()
        fixture.currentDateProvider.advanceBy(nanoseconds: 0.5.toNanoSeconds())
        let expectedAddressesB: [NSNumber] = [0x7, 0x8, 0x9]
        let expectedThreadMetadataB = SentryProfileTestFixture.ThreadMetadata(id: 4, priority: 5, name: "test-thread2")
        try addMockSamples(threadMetadata: expectedThreadMetadataB, addresses: expectedAddressesB)

        // finish span B and check profile data
        spanB.finish()
        try self.assertValidTraceProfileData(expectedAddresses: expectedAddressesB, expectedThreadMetadata: [expectedThreadMetadataB])

        // finish span A and check profile data
        spanA.finish()
        try self.assertValidTraceProfileData(expectedAddresses: expectedAddressesA, expectedThreadMetadata: [expectedThreadMetadataA])
    }

    func testProfileTimeoutTimer() throws {
        try performTraceProfilingTest(shouldTimeOut: true)
    }

    func testStartTransaction_ProfilingDataIsValid() throws {
        try performTraceProfilingTest()
    }

    func testProfilingDataContainsEnvironmentSetFromOptions() throws {
        let expectedEnvironment = "test-environment"
        fixture.options.environment = expectedEnvironment
        try performTraceProfilingTest(transactionEnvironment: expectedEnvironment)
    }

#if !os(macOS)
    func testProfileWithTransactionContainingStartupSpansForColdStart() throws {
        try performTraceProfilingTest(uikitParameters: UIKitParameters(launchType: .cold, prewarmed: false))
    }

    func testProfileWithTransactionContainingStartupSpansForWarmStart() throws {
        try performTraceProfilingTest(uikitParameters: UIKitParameters(launchType: .warm, prewarmed: false))
    }

    func testProfileWithTransactionContainingStartupSpansForPrewarmedStart() throws {
        try performTraceProfilingTest(uikitParameters: UIKitParameters(launchType: .warm, prewarmed: true))
    }
#endif // !os(macOS)

    func testProfilingDataContainsEnvironmentSetFromConfigureScope() throws {
        let expectedEnvironment = "test-environment"
        fixture.hub.configureScope { scope in
            scope.setEnvironment(expectedEnvironment)
        }
        try performTraceProfilingTest(transactionEnvironment: expectedEnvironment)
    }

    func testStartTransaction_NotSamplingProfileUsingEnableProfiling() throws {
        try assertProfilesSampler(expectedDecision: .no) { options in
            options.enableProfiling_DEPRECATED_TEST_ONLY = false
        }
    }

    func testStartTransaction_SamplingProfileUsingEnableProfiling() throws {
        try assertProfilesSampler(expectedDecision: .yes) { options in
            options.enableProfiling_DEPRECATED_TEST_ONLY = true
        }
    }

    func testStartTransaction_NotSamplingProfileUsingSampleRate() throws {
        try assertProfilesSampler(expectedDecision: .no) { options in
            options.profilesSampleRate = 0.49
        }
    }

    func testStartTransaction_SamplingProfileUsingSampleRate() throws {
        try assertProfilesSampler(expectedDecision: .yes) { options in
            options.profilesSampleRate = 0.5
        }
    }

    func testStartTransaction_SamplingProfileUsingProfilesSampler() throws {
        try assertProfilesSampler(expectedDecision: .yes) { options in
            options.profilesSampler = { _ in return 0.51 }
        }
    }

    func testStartTransaction_WhenProfilesSampleRateAndProfilesSamplerNil() throws {
        try assertProfilesSampler(expectedDecision: .no) { options in
            options.profilesSampleRate = 0
            options.profilesSampler = { _ in return nil }
        }
    }

    func testStartTransaction_WhenProfilesSamplerOutOfRange_TooBig() throws {
        try assertProfilesSampler(expectedDecision: .no) { options in
            options.profilesSampler = { _ in return 1.01 }
        }
    }

    func testStartTransaction_WhenProfilesSamplersOutOfRange_TooSmall() throws {
        try assertProfilesSampler(expectedDecision: .no) { options in
            options.profilesSampler = { _ in return -0.01 }
        }
    }

    /// based on ``SentryTracerTests.testFinish_WithoutHub_DoesntCaptureTransaction``
    func testProfilerCleanedUpAfterTransactionDiscarded_NoHub() throws {
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        func performTransaction() {
            let sut = SentryTracer(transactionContext: TransactionContext(name: fixture.transactionName, operation: fixture.transactionOperation), hub: nil)
            XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
            sut.finish()
        }
        performTransaction()
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        XCTAssertEqual(self.fixture.client?.captureEventWithScopeInvocations.count, 0)
    }

    /// based on ``SentryTracerTests.testFinish_WaitForAllChildren_ExceedsMaxDuration_NoTransactionCaptured``
    func testProfilerCleanedUpAfterTransactionDiscarded_ExceedsMaxDuration() throws {
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        func performTransaction() throws {
            let sut = try fixture.newTransaction(automaticTransaction: true)
            XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(1))
            fixture.currentDateProvider.advance(by: 500)
            sut.finish()
        }
        try performTransaction()
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        XCTAssertEqual(self.fixture.client?.captureEventWithScopeInvocations.count, 0)
    }

    func testProfilerCleanedUpAfterInFlightTransactionDeallocated() throws {
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        func performTransaction() throws {
            let sut = try fixture.newTransaction(automaticTransaction: true)
            XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(1))
            XCTAssertFalse(sut.isFinished)
        }
        try performTransaction()
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        XCTAssertEqual(self.fixture.client?.captureEventWithScopeInvocations.count, 0)
    }

    /// based on ``SentryTracerTests.testFinish_IdleTimeout_ExceedsMaxDuration_NoTransactionCaptured``
    func testProfilerCleanedUpAfterTransactionDiscarded_IdleTimeout_ExceedsMaxDuration() throws {
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        func performTransaction() throws {
            let sut = try fixture.newTransaction(automaticTransaction: true, idleTimeout: 1)
            XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(1))
            fixture.currentDateProvider.advance(by: 500)
            sut.finish()
        }
        try performTransaction()
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        XCTAssertEqual(self.fixture.client?.captureEventWithScopeInvocations.count, 0)
    }

    /// based on ``SentryTracerTests.testIdleTimeout_NoChildren_TransactionNotCaptured``
    func testProfilerCleanedUpAfterTransactionDiscarded_IdleTimeout_NoChildren() throws {
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        func performTransaction() throws {
            let span = try fixture.newTransaction(automaticTransaction: true, idleTimeout: 1)
            XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(1))
            fixture.currentDateProvider.advance(by: 500)
            fixture.dispatchQueueWrapper.invokeLastDispatchAfter()
            XCTAssert(span.isFinished)
        }
        try performTransaction()
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        XCTAssertEqual(self.fixture.client?.captureEventWithScopeInvocations.count, 0)
    }

    /// based on ``SentryTracerTests.testIdleTransaction_CreatingDispatchBlockFails_NoTransactionCaptured``
    func testProfilerCleanedUpAfterTransactionDiscarded_IdleTransaction_CreatingDispatchBlockFails() throws {
        fixture.dispatchQueueWrapper.createDispatchBlockReturnsNULL = true
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        func performTransaction() throws {
            let span = try fixture.newTransaction(automaticTransaction: true, idleTimeout: 1)
            XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(1))
            fixture.currentDateProvider.advance(by: 500)
            span.finish()
        }
        try performTransaction()
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        XCTAssertEqual(self.fixture.client?.captureEventWithScopeInvocations.count, 0)
    }

#if !os(macOS)
    /// based on ``SentryTracerTests.testFinish_WaitForAllChildren_StartTimeModified_NoTransactionCaptured``
    func testProfilerCleanedUpAfterTransactionDiscarded_WaitForAllChildren_StartTimeModified() throws {
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        let appStartMeasurement = fixture.getAppStartMeasurement(type: .cold)
        SentrySDK.setAppStartMeasurement(appStartMeasurement)
        fixture.currentDateProvider.advance(by: 1)
        func performTransaction() throws {
            let sut = try fixture.newTransaction(testingAppLaunchSpans: true, automaticTransaction: true)
            XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(1))
            fixture.currentDateProvider.advance(by: 499)
            sut.finish()
        }
        try performTransaction()
        XCTAssertEqual(SentryTraceProfiler.currentProfiledTracers(), UInt(0))
        XCTAssertEqual(self.fixture.client?.captureEventWithScopeInvocations.count, 0)
    }

    // test that receiving a backgrounding notification stops the profiler
    func testTraceProfilerStopsOnBackgrounding() throws {
        let span = try fixture.newTransaction()
        XCTAssert(try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler()).isRunning())
        fixture.currentDateProvider.advance(by: 1)
        fixture.notificationCenter.post(Notification(name: UIApplication.willResignActiveNotification, object: nil))
        XCTAssertFalse(try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler()).isRunning())
        span.finish() // this isn't germane to the test, but we need the span to be retained throughout the test, and this satisfies the unused variable check
    }
#endif // !os(macOS)
}

private extension SentryTraceProfilerTests {
    func getLatestProfileData() throws -> Data {
        let envelope = try XCTUnwrap(self.fixture.client?.captureEventWithScopeInvocations.last)

        XCTAssertEqual(1, envelope.additionalEnvelopeItems.count)
        let profileItem = try XCTUnwrap(envelope.additionalEnvelopeItems.first)

        XCTAssertEqual("profile", profileItem.header.type)
        return profileItem.data
    }

    func getLatestTransaction() throws -> Transaction {
        let envelope = try XCTUnwrap(self.fixture.client?.captureEventWithScopeInvocations.last)
        return try XCTUnwrap(envelope.event as? Transaction)
    }

    func addMockSamples(threadMetadata: SentryProfileTestFixture.ThreadMetadata = SentryProfileTestFixture.ThreadMetadata(id: 1, priority: 2, name: "main"), addresses: [NSNumber] = [0x3, 0x4, 0x5]) throws {
        let state = try XCTUnwrap(SentryTraceProfiler.getCurrentProfiler()).state
        fixture.currentDateProvider.advanceBy(nanoseconds: 1)
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: threadMetadata.id, threadPriority: threadMetadata.priority, threadName: threadMetadata.name, addresses: addresses)
        fixture.currentDateProvider.advanceBy(nanoseconds: 1)
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: threadMetadata.id, threadPriority: threadMetadata.priority, threadName: threadMetadata.name, addresses: addresses)
        fixture.currentDateProvider.advanceBy(nanoseconds: 1)
        SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: threadMetadata.id, threadPriority: threadMetadata.priority, threadName: threadMetadata.name, addresses: addresses)
    }

    struct UIKitParameters {
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        var launchType: SentryAppStartType
        var prewarmed: Bool
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    }

    func performTraceProfilingTest(transactionEnvironment: String = kSentryDefaultEnvironment, shouldTimeOut: Bool = false, uikitParameters: UIKitParameters? = nil) throws {
        var testingAppLaunchSpans = false
        
#if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        if let uikitParameters = uikitParameters {
            testingAppLaunchSpans = true
            let appStartMeasurement = fixture.getAppStartMeasurement(type: uikitParameters.launchType, preWarmed: uikitParameters.prewarmed)
            SentrySDK.setAppStartMeasurement(appStartMeasurement)
        }
#endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

        let span = try fixture.newTransaction(testingAppLaunchSpans: testingAppLaunchSpans)

        try addMockSamples()
        fixture.currentDateProvider.advance(by: 31)
        if shouldTimeOut {
            self.fixture.timeoutTimerFactory.fire()
        }

        let exp = expectation(description: "finished span")
        DispatchQueue.main.async {
            span.finish()
            exp.fulfill()
        }

        waitForExpectations(timeout: 1)

        try self.assertValidTraceProfileData(transactionEnvironment: transactionEnvironment, shouldTimeout: shouldTimeOut, appStartProfile: testingAppLaunchSpans)
    }

    func assertMetricsPayload(oneLessEnergyReading: Bool = true, expectedMetricsReadingsPerBatchOverride: Int? = nil) throws {
        let profileData = try self.getLatestProfileData()
        let transaction = try getLatestTransaction()
        let profile = try XCTUnwrap(JSONSerialization.jsonObject(with: profileData) as? [String: Any])
        let measurements = try XCTUnwrap(profile["measurements"] as? [String: Any])
        let expectedUsageReadings = expectedMetricsReadingsPerBatchOverride ?? fixture.mockMetrics.readingsPerBatch + 2 // including one sample at the start and the end

        try assertMetricValue(measurements: measurements, key: kSentryMetricProfilerSerializationKeyCPUUsage, numberOfReadings: expectedUsageReadings, expectedValue: fixture.mockMetrics.cpuUsage, transaction: transaction, expectedUnits: kSentryMetricProfilerSerializationUnitPercentage)

        try assertMetricValue(measurements: measurements, key: kSentryMetricProfilerSerializationKeyMemoryFootprint, numberOfReadings: expectedUsageReadings, expectedValue: fixture.mockMetrics.memoryFootprint, transaction: transaction, expectedUnits: kSentryMetricProfilerSerializationUnitBytes)

        // we wind up with one less energy reading for the first concurrent span's metric sample. since we must use the difference between readings to get actual values, the first one is only the baseline reading.
        let expectedEnergyReadings = oneLessEnergyReading ? expectedUsageReadings - 1 : expectedUsageReadings
        try assertMetricValue(measurements: measurements, key: kSentryMetricProfilerSerializationKeyCPUEnergyUsage, numberOfReadings: expectedEnergyReadings, expectedValue: fixture.mockMetrics.cpuEnergyUsage, transaction: transaction, expectedUnits: kSentryMetricProfilerSerializationUnitNanoJoules)

#if !os(macOS)
        try assertMetricEntries(measurements: measurements, key: kSentryProfilerSerializationKeySlowFrameRenders, expectedEntries: fixture.expectedTraceProfileSlowFrames, transaction: transaction)
        try assertMetricEntries(measurements: measurements, key: kSentryProfilerSerializationKeyFrozenFrameRenders, expectedEntries: fixture.expectedTraceProfileFrozenFrames, transaction: transaction)
        try assertMetricEntries(measurements: measurements, key: kSentryProfilerSerializationKeyFrameRates, expectedEntries: fixture.expectedTraceProfileFrameRateChanges, transaction: transaction)
#endif // !os(macOS)
    }

    func sortedByTimestamps(_ entries: [[String: Any]]) throws -> [[String: Any]] {
        try entries.sorted { a, b in
            let aValue = try XCTUnwrap(a["elapsed_since_start_ns"] as? String)
            let aIntValue = try XCTUnwrap(UInt64(aValue))
            let bValue = try XCTUnwrap(b["elapsed_since_start_ns"] as? String)
            let bIntValue = try XCTUnwrap(UInt64(bValue))
            return aIntValue < bIntValue
        }
    }

    func printTimestamps(entries: [[String: Any]]) -> [NSString] {
        entries.compactMap({ $0["elapsed_since_start_ns"] as? NSString })
    }

    func assertMetricEntries(measurements: [String: Any], key: String, expectedEntries: [[String: Any]], transaction: Transaction) throws {
        let metricContainer = try XCTUnwrap(measurements[key] as? [String: Any])
        let actualEntries = try XCTUnwrap(metricContainer["values"] as? [[String: Any]])
        let sortedActualEntries = try sortedByTimestamps(actualEntries)
        let sortedExpectedEntries = try sortedByTimestamps(expectedEntries)

        guard actualEntries.count == expectedEntries.count else {
            XCTFail("Wrong number of values under \(key). expected: \(printTimestamps(entries: sortedExpectedEntries)); actual: \(printTimestamps(entries: sortedActualEntries)); transaction start time: \(transaction.startSystemTime)")
            return
        }

        for i in 0..<actualEntries.count {
            let actualEntry = sortedActualEntries[i]
            let expectedEntry = sortedExpectedEntries[i]

            let actualTimestamp = try XCTUnwrap(actualEntry["elapsed_since_start_ns"] as? NSString)
            let expectedTimestamp = String(UInt64(try XCTUnwrap(expectedEntry["elapsed_since_start_ns"] as? NSString).longLongValue) - transaction.startSystemTime) as NSString
            XCTAssertEqual(actualTimestamp, expectedTimestamp)
            try assertTimestampOccursWithinTransaction(timestamp: actualTimestamp, transaction: transaction)

            let actualValue = try XCTUnwrap(actualEntry["value"] as? NSNumber)
            let expectedValue = try XCTUnwrap(expectedEntry["value"] as? NSNumber)
            XCTAssertEqual(actualValue, expectedValue)
        }
    }

    func assertMetricValue<T: Equatable>(measurements: [String: Any], key: String, numberOfReadings: Int, expectedValue: T? = nil, transaction: Transaction, expectedUnits: String) throws {
        let metricContainer = try XCTUnwrap(measurements[key] as? [String: Any])
        let values = try XCTUnwrap(metricContainer["values"] as? [[String: Any]])
        XCTAssertEqual(values.count, numberOfReadings, "Wrong number of values under \(key)")

        if let expectedValue = expectedValue {
            let actualValue = try XCTUnwrap(values.element(at: 1)?["value"] as? T)
            XCTAssertEqual(actualValue, expectedValue, "Wrong value for \(key)")

            let timestamp = try XCTUnwrap(values.first?["elapsed_since_start_ns"] as? NSString)
            try assertTimestampOccursWithinTransaction(timestamp: timestamp, transaction: transaction)

            let actualUnits = try XCTUnwrap(metricContainer["unit"] as? String)
            XCTAssertEqual(actualUnits, expectedUnits)
        }
    }

    /// Assert that the relative timestamp actually falls within the transaction's duration, so it should be between 0 and the transaction duration. The string that holds an elapsed time actually holds an unsigned long long value (due to us using unsigned 64 bit integers, which are not officially supported by JSON), but there is no Cocoa API to get that back out of a string. So, we'll just convert them to signed 64 bit integers, for which there is an API. This likely won't cause a problem because signed 64 bit ints still support large positive values that are likely to be larger than any amount of nanoseconds of a machine's uptime. We can revisit if this actually fails in practice.
    func assertTimestampOccursWithinTransaction(timestamp: NSString, transaction: Transaction) throws {
        let transactionDuration = Int64(getDurationNs(transaction.startSystemTime, transaction.endSystemTime))
        let timestampNumericValue = timestamp.longLongValue
        XCTAssertGreaterThanOrEqual(timestampNumericValue, 0)
        XCTAssertLessThanOrEqual(timestampNumericValue, transactionDuration)
    }
    
    enum SentryProfilerSwiftTestError: Error {
        case notEnoughAppStartSpans
    }

    func assertValidTraceProfileData(transactionEnvironment: String = kSentryDefaultEnvironment, shouldTimeout: Bool = false, expectedAddresses: [NSNumber]? = nil, expectedThreadMetadata: [SentryProfileTestFixture.ThreadMetadata]? = nil, appStartProfile: Bool = false) throws {
        let data = try getLatestProfileData()
        let profile = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(try XCTUnwrap(profile["version"] as? String), "1")

        let device = try XCTUnwrap(profile["device"] as? [String: Any?])
        XCTAssertNotNil(device)
        XCTAssertEqual("Apple", try XCTUnwrap(device["manufacturer"] as? String))
        XCTAssertEqual(try XCTUnwrap(device["locale"] as? String), (NSLocale.current as NSLocale).localeIdentifier)
        XCTAssertFalse(try XCTUnwrap(device["model"] as? String).isEmpty)
#if targetEnvironment(simulator)
        XCTAssertTrue(try XCTUnwrap(device["is_emulator"] as? Bool))
#else
        XCTAssertFalse(try XCTUnwrap(device["is_emulator"] as? Bool))
#endif // targetEnvironment(simulator)

        let os = try XCTUnwrap(profile["os"] as? [String: Any?])
        XCTAssertNotNil(os)
        XCTAssertNotNil(try XCTUnwrap(os["name"] as? String))
        XCTAssertFalse(try XCTUnwrap(os["version"] as? String).isEmpty)
        XCTAssertFalse(try XCTUnwrap(os["build_number"] as? String).isEmpty)

        let platform = try XCTUnwrap(profile["platform"] as? String)
        XCTAssertEqual("cocoa", platform)

        XCTAssertEqual(transactionEnvironment, try XCTUnwrap(profile["environment"] as? String))

        let bundleID = Bundle.main.object(forInfoDictionaryKey: kCFBundleIdentifierKey as String) ?? "(null)"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "(null)"
        let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) ?? "(null)"
        let expectedReleaseString = "\(bundleID)@\(version)+\(build)"
        let actualReleaseString = try XCTUnwrap(profile["release"] as? String)
        XCTAssertEqual(actualReleaseString, expectedReleaseString)

        XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: try XCTUnwrap(profile["profile_id"] as? String)))

        let debugMeta = try XCTUnwrap(profile["debug_meta"] as? [String: Any])
        let images = try XCTUnwrap(debugMeta["images"] as? [[String: Any]])
        XCTAssertFalse(images.isEmpty)
        let firstImage = try XCTUnwrap(images.first)
        XCTAssertFalse(try XCTUnwrap(firstImage["code_file"] as? String).isEmpty)
        XCTAssertFalse(try XCTUnwrap(firstImage["debug_id"] as? String).isEmpty)
        XCTAssertFalse(try XCTUnwrap(firstImage["image_addr"] as? String).isEmpty)
        XCTAssertGreaterThan(try XCTUnwrap(firstImage["image_size"] as? Int), 0)
        XCTAssertEqual(try XCTUnwrap(firstImage["type"] as? String), "macho")

        let sampledProfile = try XCTUnwrap(profile["profile"] as? [String: Any])
        let threadMetadata = try XCTUnwrap(sampledProfile["thread_metadata"] as? [String: [String: Any]])
        XCTAssertFalse(threadMetadata.isEmpty)
        if let expectedThreadMetadata = expectedThreadMetadata {
            try expectedThreadMetadata.forEach {
                let actualThreadMetadata = try XCTUnwrap(threadMetadata["\($0.id)"])
                let actualThreadPriority = try XCTUnwrap(actualThreadMetadata["priority"] as? Int32)
                XCTAssertEqual(actualThreadPriority, $0.priority)
                let actualThreadName = try XCTUnwrap(actualThreadMetadata["name"] as? String)
                XCTAssertEqual(actualThreadName, $0.name)
            }
        } else {
            XCTAssertFalse(try threadMetadata.values.compactMap { $0["priority"] }.filter { try XCTUnwrap($0 as? Int) > 0 }.isEmpty)
            XCTAssertFalse(try threadMetadata.values.compactMap { $0["name"] }.filter { try XCTUnwrap($0 as? String) == "main" }.isEmpty)
        }

        let samples = try XCTUnwrap(sampledProfile["samples"] as? [[String: Any]])
        XCTAssertFalse(samples.isEmpty)

        let frames = try XCTUnwrap(sampledProfile["frames"] as? [[String: Any]])
        XCTAssertFalse(frames.isEmpty)
        XCTAssertFalse(try XCTUnwrap(frames.first?["instruction_addr"] as? String).isEmpty)
        XCTAssertFalse(try XCTUnwrap(frames.first?["function"] as? String).isEmpty)

        let stacks = try XCTUnwrap(sampledProfile["stacks"] as? [[Int]])
        var foundAtLeastOneNonEmptySample = false
        XCTAssertFalse(stacks.isEmpty)
        for stack in stacks {
            guard !stack.isEmpty else { continue }
            foundAtLeastOneNonEmptySample = true
            for frameIdx in stack {
                XCTAssertNotNil(frames[frameIdx])
            }
        }
        XCTAssert(foundAtLeastOneNonEmptySample)

        let latestTransaction = try getLatestTransaction()
        let linkedTransactionInfo = try XCTUnwrap(profile["transaction"] as? [String: Any])

        let profileTimestampString = try XCTUnwrap(profile["timestamp"] as? String)
        
        let latestTransactionTimestamp = try XCTUnwrap(latestTransaction.startTimestamp)
        var startTimestampString = sentry_toIso8601String(latestTransactionTimestamp)
        #if !os(macOS)
        if appStartProfile {
            let runtimeInitTimestamp = try XCTUnwrap(SentrySDK.getAppStartMeasurement()?.runtimeInitTimestamp)
            startTimestampString = sentry_toIso8601String(runtimeInitTimestamp)
        }
        #endif // !os(macOS)
                    
        XCTAssertEqual(profileTimestampString, startTimestampString)

        XCTAssertEqual(fixture.transactionName, latestTransaction.transaction)
        XCTAssertEqual(fixture.transactionName, try XCTUnwrap(linkedTransactionInfo["name"] as? String))

        let linkedTransactionId = SentryId(uuidString: try XCTUnwrap(linkedTransactionInfo["id"] as? String))
        XCTAssertEqual(latestTransaction.eventId, linkedTransactionId)
        XCTAssertNotEqual(SentryId.empty, linkedTransactionId)

        let linkedTransactionTraceId = SentryId(uuidString: try XCTUnwrap(linkedTransactionInfo["trace_id"] as? String))
        XCTAssertEqual(latestTransaction.trace.traceId, linkedTransactionTraceId)
        XCTAssertNotEqual(SentryId.empty, linkedTransactionTraceId)

        let activeThreadId = try XCTUnwrap(linkedTransactionInfo["active_thread_id"] as? NSNumber)
        XCTAssertEqual(activeThreadId, latestTransaction.trace.transactionContext.sentry_threadInfo().threadId)

        for sample in samples {
            let timestamp = try XCTUnwrap(sample["elapsed_since_start_ns"] as? NSString)
            try assertTimestampOccursWithinTransaction(timestamp: timestamp, transaction: latestTransaction)
            XCTAssertNotNil(sample["thread_id"])
            let stackIDEntry = try XCTUnwrap(sample["stack_id"])
            let stackID = try XCTUnwrap(stackIDEntry as? Int)
            XCTAssertNotNil(stacks[stackID])
        }

        if shouldTimeout {
            XCTAssertEqual(try XCTUnwrap(profile["truncation_reason"] as? String), sentry_profilerTruncationReasonName(SentryProfilerTruncationReason.timeout))
        }
    }

    func assertProfilesSampler(expectedDecision: SentrySampleDecision, options: (Options) -> Void) throws {
        let fixtureOptions = fixture.options
        fixtureOptions.tracesSampleRate = 1.0
        fixtureOptions.profilesSampleRate = 0
        fixtureOptions.profilesSampler = { _ in
            switch expectedDecision {
            case .undecided, .no:
                return NSNumber(value: 0)
            case .yes:
                return NSNumber(value: 1)
            @unknown default:
                XCTFail("Unexpected value for sample decision")
                return NSNumber(value: 0)
            }
        }
        options(fixtureOptions)
        
        let span = try fixture.newTransaction()
        if expectedDecision == .yes {
            try addMockSamples()
        }
        fixture.currentDateProvider.advance(by: 5)
        span.finish()

        let client = try XCTUnwrap(self.fixture.client)

        switch expectedDecision {
        case .undecided, .no:
            let event = try XCTUnwrap(client.captureEventWithScopeInvocations.first)
            XCTAssertEqual(0, event.additionalEnvelopeItems.count)
        case .yes:
            let event = try XCTUnwrap(client.captureEventWithScopeInvocations.first)
            XCTAssertEqual(1, event.additionalEnvelopeItems.count)
        @unknown default:
            XCTFail("Unexpected value for sample decision")
        }
    }
}
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
