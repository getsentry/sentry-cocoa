import _SentryPrivate
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

final class SentryContinuousProfilerTests: XCTestCase {
    private var fixture: SentryProfileTestFixture!
    
    override class func setUp() {
        super.setUp()
        SentryLog.configure(true, diagnosticLevel: .debug)
    }
    
    override func setUp() {
        super.setUp()
        fixture = SentryProfileTestFixture()
        fixture.options.profilesSampleRate = nil
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testStartingAndStoppingContinuousProfiler() throws {
        try performContinuousProfilingTest()
    }
    
    func testProfilingDataContainsEnvironmentSetFromOptions() throws {
        let expectedEnvironment = "test-environment"
        fixture.options.environment = expectedEnvironment
        try performContinuousProfilingTest(expectedEnvironment: expectedEnvironment)
    }
    
    func testProfilingDataContainsEnvironmentSetFromConfigureScope() throws {
        let expectedEnvironment = "test-environment"
        fixture.hub.configureScope { scope in
            scope.setEnvironment(expectedEnvironment)
        }
        try performContinuousProfilingTest(expectedEnvironment: expectedEnvironment)
    }

    func testProfilingDataContainsEnvironmentSetFromConfigureScopeAndOptions() throws {
        let expectedEnvironment = "test-environment"
        fixture.options.environment = "options-environment"
        fixture.hub.configureScope { scope in
            scope.setEnvironment(expectedEnvironment)
        }
        try performContinuousProfilingTest(expectedEnvironment: expectedEnvironment)
    }

    func testProfilingDataContainsEnvironmentSetFromConfigureScopeAndOptionsAndEvent() throws {
        let expectedEnvironment = "test-environment"
        fixture.options.environment = "options-environment"
        fixture.hub.configureScope { scope in
            scope.setEnvironment(expectedEnvironment)
        }
        let event = Event()
        event.environment = "event-environment"
        fixture.hub.capture(event: event)
        try performContinuousProfilingTest(expectedEnvironment: expectedEnvironment)
    }

    func testStartingContinuousProfilerWithSampleRateOne() throws {
        fixture.options.profilesSampleRate = 1
        try performContinuousProfilingTest()
    }

    func testStartingContinuousProfilerWithZeroSampleRate() throws {
        fixture.options.profilesSampleRate = 0
        try performContinuousProfilingTest()
    }    

    #if !os(macOS)
    // test that receiving a background notification stops the continuous
    // profiler after it has been started manually
    func testStoppingContinuousProfilerStopsOnBackground() throws {
        SentryContinuousProfiler.start()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        fixture.notificationCenter.post(Notification(name: UIApplication.willResignActiveNotification, object: nil))
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }
    #endif // !os(macOS)

    // test that after starting the continuous profiler and waiting for more
    // than 30 seconds, the profiler is still running; (tests that the trace
    // profiler's timeout timer does not affect the continuous profiler
    func testContinuousProfilerNotStoppedAfter30Seconds() throws {
        SentryContinuousProfiler.start()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        fixture.currentDateProvider.advanceBy(interval: 31)
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
    }
    
    func testClosingSDKStopsProfile() {
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        SentryContinuousProfiler.start()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        SentrySDK.close()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }
    
    func testStartingAPerformanceTransactionDoesNotStartProfiler() throws {
        let manualSpan = try fixture.newTransaction()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        let automaticSpan = try fixture.newTransaction(automaticTransaction: true)
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        manualSpan.finish()
        automaticSpan.finish()
    }
}

private extension SentryContinuousProfilerTests {
    func addMockSamples(mockAddresses: [NSNumber]) throws {
        let mockThreadMetadata = SentryProfileTestFixture.ThreadMetadata(id: 1, priority: 2, name: "main")
        let state = try XCTUnwrap(SentryContinuousProfiler.profiler()?.state)
        for _ in 0..<Int(kSentryProfilerChunkExpirationInterval) {
            fixture.currentDateProvider.advanceBy(interval: 1)
            SentryProfilerMocksSwiftCompatible.appendMockBacktrace(to: state, threadID: mockThreadMetadata.id, threadPriority: mockThreadMetadata.priority, threadName: mockThreadMetadata.name, addresses: mockAddresses)
        }
    }
    
    func performContinuousProfilingTest(expectedEnvironment: String = kSentryDefaultEnvironment) throws {
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
        SentryContinuousProfiler.start()
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        
        func runTestPart(expectedAddresses: [NSNumber], mockMetrics: SentryProfileTestFixture.MockMetric, countMetricsReadingAtProfileStart: Bool = true) throws {
            fixture.setMockMetrics(mockMetrics)
            try addMockSamples(mockAddresses: expectedAddresses)
            try fixture.gatherMockedContinuousProfileMetrics()
            try addMockSamples(mockAddresses: expectedAddresses)
            fixture.currentDateProvider.advanceBy(interval: 1)
            fixture.timeoutTimerFactory.fire()
            XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
            try assertValidData(expectedEnvironment: expectedEnvironment, expectedAddresses: expectedAddresses, countMetricsReadingAtProfileStart: countMetricsReadingAtProfileStart)
    #if  os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            fixture.resetProfileGPUExpectations()
    #endif //  os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
            fixture.currentDateProvider.advanceBy(interval: 1)
        }
        
        try runTestPart(expectedAddresses: [0x1, 0x2, 0x3], mockMetrics: SentryProfileTestFixture.MockMetric())
        try runTestPart(expectedAddresses: [0x4, 0x5, 0x6], mockMetrics: SentryProfileTestFixture.MockMetric(cpuUsage: 1.23, memoryFootprint: 456, cpuEnergyUsage: 7), countMetricsReadingAtProfileStart: false)
        try runTestPart(expectedAddresses: [0x7, 0x8, 0x9], mockMetrics: SentryProfileTestFixture.MockMetric(cpuUsage: 9.87, memoryFootprint: 654, cpuEnergyUsage: 3), countMetricsReadingAtProfileStart: false)
        
        XCTAssert(SentryContinuousProfiler.isCurrentlyProfiling())
        SentryContinuousProfiler.stop()
        XCTAssertFalse(SentryContinuousProfiler.isCurrentlyProfiling())
    }
    
    func assertValidData(expectedEnvironment: String, expectedAddresses: [NSNumber]?, countMetricsReadingAtProfileStart: Bool = true) throws {
        let envelope = try XCTUnwrap(self.fixture.client?.captureEnvelopeInvocations.last)
        XCTAssertEqual(1, envelope.items.count)
        let profileItem = try XCTUnwrap(envelope.items.first)
        XCTAssertEqual("profile_chunk", profileItem.header.type)
        let data = profileItem.data
        let profile = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(try XCTUnwrap(profile["version"] as? String), "2")

        let platform = try XCTUnwrap(profile["platform"] as? String)
        XCTAssertEqual("cocoa", platform)

        XCTAssertEqual(expectedEnvironment, try XCTUnwrap(profile["environment"] as? String))

        let bundleID = Bundle.main.object(forInfoDictionaryKey: kCFBundleIdentifierKey as String) ?? "(null)"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "(null)"
        let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) ?? "(null)"
        let expectedReleaseString = "\(bundleID)@\(version)+\(build)"
        let actualReleaseString = try XCTUnwrap(profile["release"] as? String)
        XCTAssertEqual(actualReleaseString, expectedReleaseString)

        XCTAssertNotEqual(SentryId.empty, SentryId(uuidString: try XCTUnwrap(profile["profiler_id"] as? String)))

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
        XCTAssertFalse(try threadMetadata.values.compactMap { $0["priority"] }.filter { try XCTUnwrap($0 as? Int) > 0 }.isEmpty)
        XCTAssertFalse(try threadMetadata.values.compactMap { $0["name"] }.filter { try XCTUnwrap($0 as? String) == "main" }.isEmpty)

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

        for sample in samples {
            XCTAssertNotNil(sample["timestamp"] as? NSNumber)
            XCTAssertNotNil(sample["thread_id"])
            let stackIDEntry = try XCTUnwrap(sample["stack_id"])
            let stackID = try XCTUnwrap(stackIDEntry as? Int)
            XCTAssertNotNil(stacks[stackID])
        }

        let measurements = try XCTUnwrap(profile["measurements"] as? [String: Any])

        let chunkStartTime = try XCTUnwrap(samples.first?["timestamp"] as? TimeInterval)
        let chunkEndTime = try XCTUnwrap(samples.last?["timestamp"] as? TimeInterval)
 
        // the metric profiler takes a reading right at the start of a profile, so we also get that in addition to the ones that are mocked in these tests
        let expectedReadingsPerBatch = fixture.mockMetrics.readingsPerBatch + (countMetricsReadingAtProfileStart ? 1 : 0)
        
        try assertMetricValue(measurements: measurements, key: kSentryMetricProfilerSerializationKeyCPUUsage, expectedValue: fixture.mockMetrics.cpuUsage, expectedUnits: kSentryMetricProfilerSerializationUnitPercentage, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime, readingsPerBatch: expectedReadingsPerBatch)

        try assertMetricValue(measurements: measurements, key: kSentryMetricProfilerSerializationKeyMemoryFootprint, expectedValue: fixture.mockMetrics.memoryFootprint, expectedUnits: kSentryMetricProfilerSerializationUnitBytes, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime, readingsPerBatch: expectedReadingsPerBatch)

        // we wind up with one less energy reading for the first chunk's metric sample. since we must use the difference between readings to get actual values, the first one is only the baseline reading.
        try assertMetricValue(measurements: measurements, key: kSentryMetricProfilerSerializationKeyCPUEnergyUsage, expectedValue: fixture.mockMetrics.cpuEnergyUsage, expectedUnits: kSentryMetricProfilerSerializationUnitNanoJoules, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime, readingsPerBatch: expectedReadingsPerBatch, expectOneLessEnergyReading: countMetricsReadingAtProfileStart)

#if !os(macOS)
        try assertMetricEntries(measurements: measurements, key: kSentryProfilerSerializationKeySlowFrameRenders, expectedEntries: fixture.expectedContinuousProfileSlowFrames, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime)
        try assertMetricEntries(measurements: measurements, key: kSentryProfilerSerializationKeyFrozenFrameRenders, expectedEntries: fixture.expectedContinuousProfileFrozenFrames, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime)
        try assertMetricEntries(measurements: measurements, key: kSentryProfilerSerializationKeyFrameRates, expectedEntries: fixture.expectedContinuousProfileFrameRateChanges, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime)
#endif // !os(macOS)
    }
    
    func assertMetricEntries(measurements: [String: Any], key: String, expectedEntries: [[String: Any]], chunkStartTime: TimeInterval, chunkEndTime: TimeInterval) throws {
        let metricContainer = try XCTUnwrap(measurements[key] as? [String: Any])
        let actualEntries = try XCTUnwrap(metricContainer["values"] as? [[String: NSNumber]])
        let sortedActualEntries = try sortedByTimestamps(actualEntries)
        let sortedExpectedEntries = try sortedByTimestamps(expectedEntries)

        guard actualEntries.count == expectedEntries.count else {
            XCTFail("Wrong number of values under \(key). expected: \(try printTimestamps(entries: sortedExpectedEntries)); actual: \(try printTimestamps(entries: sortedActualEntries)); chunk start time: \(chunkStartTime)")
            return
        }

        for i in 0..<actualEntries.count {
            let actualEntry = sortedActualEntries[i]
            let expectedEntry = sortedExpectedEntries[i]

            let actualTimestamp = try XCTUnwrap(actualEntry["timestamp"] as? TimeInterval)
            let expectedTimestamp = try XCTUnwrap(expectedEntry["timestamp"] as? TimeInterval)
            XCTAssertEqual(actualTimestamp, expectedTimestamp)
            try assertTimestampOccursWithinTransaction(timestamp: actualTimestamp, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime)

            let actualValue = try XCTUnwrap(actualEntry["value"] as? NSNumber)
            let expectedValue = try XCTUnwrap(expectedEntry["value"] as? NSNumber)
            XCTAssertEqual(actualValue, expectedValue)
        }
    }
    
    func sortedByTimestamps(_ entries: [[String: Any]]) throws -> [[String: Any]] {
        try entries.sorted { a, b in
            try XCTUnwrap(a["timestamp"] as? TimeInterval) < XCTUnwrap(b["timestamp"] as? TimeInterval)
        }
    }
    
    func printTimestamps(entries: [[String: Any]]) throws -> [String] {
        try entries.reduce(into: [String](), { partialResult, entry in
            partialResult.append(String(try XCTUnwrap(entry["timestamp"] as? TimeInterval)))
        })
    }

    func assertMetricValue<T: Equatable>(measurements: [String: Any], key: String, expectedValue: T? = nil, expectedUnits: String, chunkStartTime: TimeInterval, chunkEndTime: TimeInterval, readingsPerBatch: Int, expectOneLessEnergyReading: Bool = false) throws {
        let metricContainer = try XCTUnwrap(measurements[key] as? [String: Any])
        let values = try XCTUnwrap(metricContainer["values"] as? [[String: Any]])
        XCTAssertEqual(values.count, readingsPerBatch - (expectOneLessEnergyReading ? 1 : 0), "Wrong number of values under \(key); (expectOneLessEnergyReading: \(expectOneLessEnergyReading))")

        if let expectedValue = expectedValue {
            let actualValue = try XCTUnwrap(try XCTUnwrap(values.element(at: 1))["value"] as? T)
            XCTAssertEqual(actualValue, expectedValue, "Wrong value for \(key)")

            let timestamp = try XCTUnwrap(values.first?["timestamp"] as? TimeInterval)
            try assertTimestampOccursWithinTransaction(timestamp: timestamp, chunkStartTime: chunkStartTime, chunkEndTime: chunkEndTime)

            let actualUnits = try XCTUnwrap(metricContainer["unit"] as? String)
            XCTAssertEqual(actualUnits, expectedUnits)
        }
    }
    
    /// Assert that the absolute timestamp actually falls within the chunk's duration, so it should be between 0 and the chunk duration.
    func assertTimestampOccursWithinTransaction(timestamp: TimeInterval, chunkStartTime: TimeInterval, chunkEndTime: TimeInterval) throws {
        XCTAssertGreaterThanOrEqual(timestamp, 0)
        XCTAssertLessThanOrEqual(timestamp, chunkEndTime)
    }
}

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
