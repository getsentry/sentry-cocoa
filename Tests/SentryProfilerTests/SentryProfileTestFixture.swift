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
    
    lazy var systemWrapper = TestSentrySystemWrapper()
    lazy var processInfoWrapper = TestSentryNSProcessInfoWrapper()
    lazy var dispatchFactory = TestDispatchFactory()
    var metricTimerFactory: TestDispatchSourceWrapper?
    lazy var timeoutTimerFactory = TestSentryNSTimerFactory()
    let dispatchQueueWrapper = TestSentryDispatchQueueWrapper()
    
    let currentDateProvider = TestCurrentDateProvider()
    
#if !os(macOS)
    lazy var displayLinkWrapper = TestDisplayLinkWrapper(dateProvider: currentDateProvider)
    lazy var framesTracker = SentryFramesTracker(displayLinkWrapper: displayLinkWrapper, dateProvider: currentDateProvider, dispatchQueueWrapper: SentryDispatchQueueWrapper(), keepDelayedFramesDuration: 0)
#endif // !os(macOS)
    
    init() {
        options = Options()
        options.dsn = SentryProfileTestFixture.dsnAsString
        client = TestClient(options: options)
        hub = SentryHub(client: client, andScope: scope)
        hub.bindClient(client)
        SentrySDK.setCurrentHub(hub)
        
        SentryDependencyContainer.sharedInstance().dateProvider = currentDateProvider
        options.profilesSampleRate = 1.0
        options.tracesSampleRate = 1.0
        
        SentryDependencyContainer.sharedInstance().systemWrapper = systemWrapper
        SentryDependencyContainer.sharedInstance().processInfoWrapper = processInfoWrapper
        dispatchFactory.vendedSourceHandler = { eventHandler in
            self.metricTimerFactory = eventHandler
        }
        SentryDependencyContainer.sharedInstance().dispatchFactory = dispatchFactory
        SentryDependencyContainer.sharedInstance().timerFactory = timeoutTimerFactory
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = dispatchQueueWrapper
        
        SentryDependencyContainer.sharedInstance().random = TestRandom(value: 0.5)
        
        systemWrapper.overrides.cpuUsage = NSNumber(value: mockCPUUsage)
        systemWrapper.overrides.memoryFootprintBytes = mockMemoryFootprint
        systemWrapper.overrides.cpuEnergyUsage = 0
        
#if !os(macOS)
        SentryDependencyContainer.sharedInstance().framesTracker = framesTracker
        framesTracker.start()
        displayLinkWrapper.call()
#endif // !os(macOS)
    }
    
    /// Advance the mock date provider, start a new transaction and return its handle.
    func newTransaction(testingAppLaunchSpans: Bool = false, automaticTransaction: Bool = false, idleTimeout: TimeInterval? = nil) throws -> SentryTracer {
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
    
    let mockCPUUsage = 66.6
    let mockMemoryFootprint: SentryRAMBytes = 123_455
    let mockEnergyUsage: NSNumber = 5
    let mockUsageReadingsPerBatch = 3
    
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
    
    func gatherMockedMetrics(span: Span) throws {
        // clear out any errors that might've been set in previous calls
        systemWrapper.overrides.cpuUsageError = nil
        systemWrapper.overrides.memoryFootprintError = nil
        systemWrapper.overrides.cpuEnergyUsageError = nil
        
        // gather mocked metrics readings
        for _ in 0..<mockUsageReadingsPerBatch {
            self.metricTimerFactory?.fire()
            
            // because energy readings are computed as the difference between sequential cumulative readings, we must increment the mock value by the expected result each iteration
            systemWrapper.overrides.cpuEnergyUsage = NSNumber(value: systemWrapper.overrides.cpuEnergyUsage!.intValue + mockEnergyUsage.intValue)
        }
        
#if !os(macOS)
        var shouldRecordFrameRateExpectation = true
        
        func changeFrameRate(_ new: FrameRate) {
            displayLinkWrapper.changeFrameRate(new)
            shouldRecordFrameRateExpectation = true
        }
        
        func renderGPUFrame(_ type: GPUFrame) {
            switch type {
            case .normal:
                let currentSystemTime: UInt64 = currentDateProvider.systemTime()
                print("expect normal frame to start at \(currentSystemTime)")
                displayLinkWrapper.normalFrame()
            case .slow:
                let duration = displayLinkWrapper.middlingSlowFrame().toNanoSeconds()
                let currentSystemTime = currentDateProvider.systemTime()
                print("will expect \(String(describing: type)) frame starting at \(currentSystemTime)")
                expectedSlowFrames.append([
                    "elapsed_since_start_ns": String(currentSystemTime),
                    "value": duration
                ])
            case .frozen:
                let duration = displayLinkWrapper.fastestFrozenFrame().toNanoSeconds()
                let currentSystemTime = currentDateProvider.systemTime()
                print("will expect \(String(describing: type)) frame starting at \(currentSystemTime)")
                expectedFrozenFrames.append([
                    "elapsed_since_start_ns": String(currentSystemTime),
                    "value": duration
                ])
            }
            if shouldRecordFrameRateExpectation {
                shouldRecordFrameRateExpectation = false
                let currentSystemTime = currentDateProvider.systemTime()
                print("will expect frame rate \(displayLinkWrapper.currentFrameRate.rawValue) at \(currentSystemTime)")
                expectedFrameRateChanges.append([
                    "elapsed_since_start_ns": String(currentSystemTime),
                    "value": NSNumber(value: displayLinkWrapper.currentFrameRate.rawValue)
                ])
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
