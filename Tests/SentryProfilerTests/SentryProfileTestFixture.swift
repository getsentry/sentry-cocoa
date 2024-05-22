import _SentryPrivate
@testable import Sentry
import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

class SentryProfileTestFixture {
    struct ThreadMetadata {
        var id: UInt64
        var priority: Int32
        var name: String
    }
    
    private static let dsnAsString = TestConstants.dsnAsString(username: "SentryProfileTestFixture")
    
    let options: Options
    let client: TestClient?
    let hub: SentryHub
    let scope = Scope()
    let message = "some message"
    let transactionName = "Some Transaction"
    let transactionOperation = "Some Operation"
    
    let systemWrapper = TestSentrySystemWrapper()
    let processInfoWrapper = TestSentryNSProcessInfoWrapper()
    let dispatchFactory = TestDispatchFactory()
    var metricTimerFactory: TestDispatchSourceWrapper?
    let timeoutTimerFactory = TestSentryNSTimerFactory()
    let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
    let notificationCenter = TestNSNotificationCenterWrapper()
    
    let currentDateProvider = TestCurrentDateProvider()
    
#if !os(macOS)
    lazy var displayLinkWrapper = TestDisplayLinkWrapper(dateProvider: currentDateProvider)
    lazy var framesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper, dateProvider: currentDateProvider, dispatchQueueWrapper: dispatchQueueWrapper, notificationCenter: TestNSNotificationCenterWrapper(), keepDelayedFramesDuration: 0)
#endif // !os(macOS)
    
    init() {
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = dispatchQueueWrapper
        SentryDependencyContainer.sharedInstance().dateProvider = currentDateProvider
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 0.5)
        SentryDependencyContainer.sharedInstance().systemWrapper = systemWrapper
        SentryDependencyContainer.sharedInstance().processInfoWrapper = processInfoWrapper
        SentryDependencyContainer.sharedInstance().dispatchFactory = dispatchFactory
        SentryDependencyContainer.sharedInstance().timerFactory = timeoutTimerFactory
        SentryDependencyContainer.sharedInstance().notificationCenterWrapper = notificationCenter
        
        mockMetrics = MockMetric()
        systemWrapper.overrides.cpuUsage = mockMetrics.cpuUsage
        systemWrapper.overrides.memoryFootprintBytes = mockMetrics.memoryFootprint
        systemWrapper.overrides.cpuEnergyUsage = 0
        systemWrapper.overrides.cpuUsageError = nil
        systemWrapper.overrides.memoryFootprintError = nil
        systemWrapper.overrides.cpuEnergyUsageError = nil
        
        options = Options()
        options.dsn = SentryProfileTestFixture.dsnAsString
        options.debug = true
        client = TestClient(options: options)
        hub = SentryHub(client: client, andScope: scope)
        hub.bindClient(client)
        SentrySDK.setCurrentHub(hub)
        
        options.profilesSampleRate = 1.0
        options.tracesSampleRate = 1.0
        
        dispatchFactory.vendedSourceHandler = { eventHandler in
            self.metricTimerFactory = eventHandler
        }
        
#if !os(macOS)
        SentryDependencyContainer.sharedInstance().framesTracker = framesTracker
        framesTracker.start()
        displayLinkWrapper.call()
#endif // !os(macOS)
    }
    
    /// Advance the mock date provider, start a new transaction and return its handle.
    func newTransaction(testingAppLaunchSpans: Bool = false, automaticTransaction: Bool = false, idleTimeout: TimeInterval? = nil, expectedProfileMetrics: MockMetric = MockMetric()) throws -> SentryTracer {
        let operation = testingAppLaunchSpans ? SentrySpanOperationUILoad : transactionOperation
        
        if automaticTransaction {
            return hub.startTransaction(
                with: TransactionContext(name: transactionName, operation: operation),
                bindToScope: false,
                customSamplingContext: [:],
                configuration: SentryTracerConfiguration(block: {
                    if let idleTimeout = idleTimeout {
                        $0.idleTimeout = idleTimeout
                    }
                    $0.waitForChildren = true
                    $0.timerFactory = self.timeoutTimerFactory
                }))
        }
        
        return try XCTUnwrap(hub.startTransaction(name: transactionName, operation: operation) as? SentryTracer)
    }
    
    // mocking
    
    public struct MockMetric {
        public var cpuUsage: NSNumber
        public var memoryFootprint: SentryRAMBytes
        public var cpuEnergyUsage: NSNumber
        public var readingsPerBatch: Int
        
        var cpuUsageError: NSError?
        var memoryFootprintError: NSError?
        var cpuEnergyUsageError: NSError?
        
        public init(cpuUsage: NSNumber = 66.6, memoryFootprint: SentryRAMBytes = 123_456, cpuEnergyUsage: NSNumber = 5, readingsPerBatch: Int = 3) {
            self.cpuUsage = cpuUsage
            self.memoryFootprint = memoryFootprint
            self.cpuEnergyUsage = cpuEnergyUsage
            self.readingsPerBatch = readingsPerBatch
        }
    }
    var mockMetrics: MockMetric
    
#if !os(macOS)
    // SentryFramesTracker starts assuming a frame rate of 60 Hz and will only log an update if it changes, so the first value here needs to be different for it to register.
    let mockFrameRateChangesPerBatch: [FrameRate] = [.high, .low, .high, .low]
    
    // Absolute timestamps must be adjusted per span when asserting
    var expectedSlowFrames = [[String: Any]]()
    var expectedFrozenFrames = [[String: Any]]()
    var expectedFrameRateChanges = [[String: Any]]()
    
    func resetGPUExpectations() {
        expectedSlowFrames = [[String: Any]]()
        expectedFrozenFrames = [[String: Any]]()
        expectedFrameRateChanges = [[String: Any]]()
    }
#endif // !os(macOS)
    
    func gatherMockedMetrics(continuousProfile: Bool = false) throws {
        // we need to manage the mocked clock and cpu usage priming differently between test cases for continuous vs trace profiles: the trace profile tests manage the clock externally to this function, because there are some more complicated setups around concurrent traces/profiles. we can do it here for continuous profiles because there's only ever one profiler running
        if continuousProfile {
            for _ in 0..<mockMetrics.readingsPerBatch {
                TestLogger.log(#line, "Expecting CPU usage: \(mockMetrics.cpuUsage); memoryFootprint: \(mockMetrics.memoryFootprint); CPU energy usage: \(mockMetrics.cpuEnergyUsage) at \(currentDateProvider.date().timeIntervalSinceReferenceDate)")
                
                // because energy readings are computed as the difference between sequential cumulative readings, we must increment the mock value by the expected result each iteration
                systemWrapper.overrides.cpuEnergyUsage = NSNumber(value: try XCTUnwrap(systemWrapper.overrides.cpuEnergyUsage).intValue + mockMetrics.cpuEnergyUsage.intValue)
                
                currentDateProvider.advance(by: 1)
                self.metricTimerFactory?.fire()
            }
        } else {
            for _ in 0..<mockMetrics.readingsPerBatch {
                self.metricTimerFactory?.fire()
                
                // because energy readings are computed as the difference between sequential cumulative readings, we must increment the mock value by the expected result each iteration
                systemWrapper.overrides.cpuEnergyUsage = NSNumber(value: try XCTUnwrap(systemWrapper.overrides.cpuEnergyUsage).intValue + mockMetrics.cpuEnergyUsage.intValue)
            }
        }
        
#if !os(macOS)
        var shouldRecordFrameRateExpectation = true
        
        func changeFrameRate(_ new: FrameRate) {
            displayLinkWrapper.changeFrameRate(new)
            shouldRecordFrameRateExpectation = true
        }
        
        func renderGPUFrame(_ type: GPUFrame) {
            func getTimestampValue() -> (value: Any, string: String) {
                var timestampValue: Any
                var timestampString: String
                if continuousProfile {
                    let actualTimestampValue = currentDateProvider.date().timeIntervalSinceReferenceDate
                    timestampValue = actualTimestampValue
                    timestampString = String(actualTimestampValue)
                } else {
                    let actualTimestampValue = currentDateProvider.systemTime()
                    timestampValue = String(actualTimestampValue)
                    timestampString = String(actualTimestampValue)
                }
                return (timestampValue, timestampString)
            }
            let timestampKey = continuousProfile ? "timestamp" : "elapsed_since_start_ns"
            switch type {
            case .normal:
                let timestamp = getTimestampValue()
                TestLogger.log(#line, "will expect normal frame starting at \(timestamp.string)")
                displayLinkWrapper.normalFrame()
            case .slow:
                let timestamp = getTimestampValue()
                TestLogger.log(#line, "will expect \(String(describing: type)) frame starting at \(timestamp.string)")
                let duration = displayLinkWrapper.middlingSlowFrame()
                var entry = [String: Any]()
                entry["value"] = continuousProfile ? duration : duration.toNanoSeconds()
                entry[timestampKey] = timestamp.value
                expectedSlowFrames.append(entry)
            case .frozen:
                let timestamp = getTimestampValue()
                TestLogger.log(#line, "will expect \(String(describing: type)) frame starting at \(timestamp.string)")
                let duration = displayLinkWrapper.fastestFrozenFrame()
                var entry = [String: Any]()
                entry["value"] = continuousProfile ? duration : duration.toNanoSeconds()
                entry[timestampKey] = timestamp.value
                expectedFrozenFrames.append(entry)
            }
            if shouldRecordFrameRateExpectation {
                shouldRecordFrameRateExpectation = false
                let timestamp = getTimestampValue()
                TestLogger.log(#line, "will expect frame rate \(displayLinkWrapper.currentFrameRate.rawValue) at \(timestamp.string)")
                var entry = [String: Any]()
                entry["value"] = NSNumber(value: displayLinkWrapper.currentFrameRate.rawValue)
                entry[timestampKey] = timestamp.value
                expectedFrameRateChanges.append(entry)
            }
        }
        
        /*
         * Mock a series of GPU frame renders of varying quality (normal/slow/frozen) and
         * refresh rate changes. The refresh rate changes ("|") happen at the same time as
         * the frame render they appear above. Time is not to scale; frozen frames last
         * much longer than the lower end of slow frames.
         *
         * refresh rate:  |---60hz--------------|---120hz------|---60hz--------------------------------------|
         * time:          N--S----N--F----------N-N-S--N-F-----N--N--S----N--F----------N--S----N--F----------
         */
        changeFrameRate(.low)
        renderGPUFrame(.normal)
        renderGPUFrame(.slow)
        renderGPUFrame(.normal)
        renderGPUFrame(.frozen)
        renderGPUFrame(.normal)
        changeFrameRate(.high)
        renderGPUFrame(.normal)
        renderGPUFrame(.slow)
        renderGPUFrame(.normal)
        renderGPUFrame(.frozen)
        renderGPUFrame(.normal)
        changeFrameRate(.low)
        renderGPUFrame(.normal)
        renderGPUFrame(.slow)
        renderGPUFrame(.normal)
        renderGPUFrame(.frozen)
        renderGPUFrame(.normal)
        changeFrameRate(.high)
        renderGPUFrame(.normal)
        renderGPUFrame(.slow)
        renderGPUFrame(.normal)
        renderGPUFrame(.frozen)
#endif // !os(macOS)
        
        // mock errors gathering cpu usage and memory footprint and fire a callback for them to ensure they don't add more information to the payload
        systemWrapper.overrides.cpuUsageError = NSError(domain: "test-error", code: 0)
        systemWrapper.overrides.memoryFootprintError = NSError(domain: "test-error", code: 1)
        systemWrapper.overrides.cpuEnergyUsageError = NSError(domain: "test-error", code: 2)
        metricTimerFactory?.fire()
        
        // clear out errors for the profile end sample collection
        systemWrapper.overrides.cpuUsageError = nil
        systemWrapper.overrides.memoryFootprintError = nil
        systemWrapper.overrides.cpuEnergyUsageError = nil
    }
    
    // app start simulation
    
    lazy var appStart = currentDateProvider.date()
    lazy var appStartSystemTime = currentDateProvider.systemTime()
    var appStartDuration = 0.5
    lazy var appStartEnd = appStart.addingTimeInterval(appStartDuration)
    
#if !os(macOS)
    func getAppStartMeasurement(type: SentryAppStartType, preWarmed: Bool = false) -> SentryAppStartMeasurement {
        let runtimeInitDuration = 0.05
        let runtimeInit = appStart.addingTimeInterval(runtimeInitDuration)
        let mainDuration = 0.15
        let main = appStart.addingTimeInterval(mainDuration)
        let didFinishLaunching = appStart.addingTimeInterval(0.3)
        appStart = preWarmed ? main : appStart
        appStartDuration = preWarmed ? appStartDuration - runtimeInitDuration - mainDuration : appStartDuration
        appStartEnd = appStart.addingTimeInterval(appStartDuration)
        return SentryAppStartMeasurement(type: type, isPreWarmed: preWarmed, appStartTimestamp: appStart, runtimeInitSystemTimestamp: appStartSystemTime, duration: appStartDuration, runtimeInitTimestamp: runtimeInit, moduleInitializationTimestamp: main,
                                         sdkStartTimestamp: appStart, didFinishLaunchingTimestamp: didFinishLaunching)
    }
#endif // !os(macOS)
}

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
