import Sentry
import SentryPrivate
import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

/**
 * We need to check if MetricKit is available for compatibility on iOS 12 and below. As there are no compiler directives for iOS versions we use canImport.
 */
#if canImport(MetricKit)
import MetricKit
#endif // canImport(MetricKit)

final class SentryMetricKitIntegrationTests: SentrySDKIntegrationTestsBase {
    
    var callStackTreePerThread: SentryMXCallStackTree!
    var callStackTreeNotPerThread: SentryMXCallStackTree!
    var timeStampBegin: Date!
    var timeStampEnd: Date!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        let contentsPerThread = try contentsOfResource("metric-kit-callstack-per-thread")
        callStackTreePerThread = try SentryMXCallStackTree.from(data: contentsPerThread)
        
        let contentsNotPerThread = try contentsOfResource("metric-kit-callstack-not-per-thread")
        callStackTreeNotPerThread = try SentryMXCallStackTree.from(data: contentsNotPerThread)
        
        // Starting from iOS 15 MetricKit payloads are delivered immediately, so
        // timeStamp and timeStampEnd match.
        timeStampBegin = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(21.23)
        timeStampEnd = timeStampBegin
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testOptionEnabled_MetricKitManagerInitialized() {
        if #available(iOS 15, macOS 12, macCatalyst 15, *) {
            let sut = SentryMetricKitIntegration()
            
            givenInstalledWithEnabled(sut)
            
            XCTAssertNotNil(Dynamic(sut).metricKitManager as SentryMXManager?)
        }
    }
    
    func testOptionDisabled_MetricKitManagerNotInitialized() {
        if #available(iOS 15, macOS 12, macCatalyst 15, *) {
            let sut = SentryMetricKitIntegration()
            
            sut.install(with: Options())
            
            XCTAssertNil(Dynamic(sut).metricKitManager as SentryMXManager?)
        }
    }
    
    func testUninstall_MetricKitManagerSetToNil() {
        if #available(iOS 15, macOS 12, macCatalyst 15, *) {
            let sut = SentryMetricKitIntegration()
            
            let options = Options()
            options.enableMetricKit = true
            sut.install(with: options)
            sut.uninstall()
            
            XCTAssertNil(Dynamic(sut).metricKitManager as SentryMXManager?)
        }
    }
    
    func testMXCrashPayloadReceived() throws {
        if #available(iOS 15, macOS 12, macCatalyst 15, *) {
            givenSDKWithHubWithScope()
            
            let sut = SentryMetricKitIntegration()
            givenInstalledWithEnabled(sut)
            
            let mxDelegate = sut as SentryMXManagerDelegate
            mxDelegate.didReceiveCrashDiagnostic(MXCrashDiagnostic(), callStackTree: callStackTreePerThread, timeStampBegin: timeStampBegin, timeStampEnd: timeStampEnd)
            
            try assertPerThread(exceptionType: "MXCrashDiagnostic", exceptionValue: "MachException Type:(null) Code:(null) Signal:(null)", exceptionMechanism: "MXCrashDiagnostic", handled: false)
        }
    }
    
    func testSetInAppIncludes_AppliesInAppToStackTrace() throws {
        if #available(iOS 15, macOS 12, macCatalyst 15, *) {
            givenSDKWithHubWithScope()
            
            let sut = SentryMetricKitIntegration()
            givenInstalledWithEnabled(sut) { options in
                options.add(inAppInclude: "iOS-Swift")
            }
            
            let mxDelegate = sut as SentryMXManagerDelegate
            mxDelegate.didReceiveCrashDiagnostic(MXCrashDiagnostic(), callStackTree: callStackTreePerThread, timeStampBegin: timeStampBegin, timeStampEnd: timeStampEnd)
            
            assertEventWithScopeCaptured { event, _, _ in
                let stacktrace = try! XCTUnwrap( event?.threads?.first?.stacktrace)
                
                let inAppFramesCount = stacktrace.frames.filter { $0.inApp as? Bool ?? false }.count
                
                XCTAssertEqual(2, inAppFramesCount)
            }
        }
    }
    
    func testCPUExceptionDiagnostic_PerThread() throws {
        if #available(iOS 15, macOS 12, macCatalyst 15, *) {
            givenSDKWithHubWithScope()
            
            let sut = SentryMetricKitIntegration()
            givenInstalledWithEnabled(sut)
            
            let mxDelegate = sut as SentryMXManagerDelegate
            mxDelegate.didReceiveCpuExceptionDiagnostic(TestMXCPUExceptionDiagnostic(), callStackTree: callStackTreePerThread, timeStampBegin: timeStampBegin, timeStampEnd: timeStampEnd)
            
            assertNothingCaptured()
        }
    }
    
    func testCPUExceptionDiagnostic_NotPerThread() throws {
        if #available(iOS 15, macOS 12, macCatalyst 15, *) {
            givenSDKWithHubWithScope()
            
            let sut = SentryMetricKitIntegration()
            givenInstalledWithEnabled(sut)
            
            let mxDelegate = sut as SentryMXManagerDelegate
            mxDelegate.didReceiveCpuExceptionDiagnostic(TestMXCPUExceptionDiagnostic(), callStackTree: callStackTreeNotPerThread, timeStampBegin: timeStampBegin, timeStampEnd: timeStampEnd)
            
            try assertNotPerThread(exceptionType: "MXCPUException", exceptionValue: "MXCPUException totalCPUTime:2.2 ms totalSampledTime:5.5 ms", exceptionMechanism: "mx_cpu_exception")
        }
    }
    
    func testDiskWriteExceptionDiagnostic() throws {
        if #available(iOS 15, macOS 12, macCatalyst 15, *) {
            givenSDKWithHubWithScope()
            
            let sut = SentryMetricKitIntegration()
            givenInstalledWithEnabled(sut)
            
            let mxDelegate = sut as SentryMXManagerDelegate
            mxDelegate.didReceiveDiskWriteExceptionDiagnostic(TestMXDiskWriteExceptionDiagnostic(), callStackTree: callStackTreeNotPerThread, timeStampBegin: timeStampBegin, timeStampEnd: timeStampEnd)
            
            try assertNotPerThread(exceptionType: "MXDiskWriteException", exceptionValue: "MXDiskWriteException totalWritesCaused:5.5 Mib", exceptionMechanism: "mx_disk_write_exception")
        }
    }
    
    func testHangDiagnostic() throws {
        if #available(iOS 15, macOS 12, macCatalyst 15, *) {
            givenSDKWithHubWithScope()
            
            let sut = SentryMetricKitIntegration()
            givenInstalledWithEnabled(sut)
            
            let mxDelegate = sut as SentryMXManagerDelegate
            mxDelegate.didReceiveHangDiagnostic(TestMXHangDiagnostic(), callStackTree: callStackTreeNotPerThread, timeStampBegin: timeStampBegin, timeStampEnd: timeStampEnd)
            
            try assertNotPerThread(exceptionType: "MXHangDiagnostic", exceptionValue: "MXHangDiagnostic hangDuration:6.6 sec", exceptionMechanism: "mx_hang_diagnostic")
        }
    }
    
    @available(iOS 15, macOS 12, macCatalyst 15, *)
    private func givenInstalledWithEnabled(_ integration: SentryMetricKitIntegration, optionsBlock: (Options) -> Void = { _ in }) {
        let options = Options()
        options.enableMetricKit = true
        optionsBlock(options)
        integration.install(with: options)
    }
    
    private func givenSDKWithHubWithScope() {
        let scope = Scope()
        scope.addBreadcrumb(TestData.crumb)
        scope.addAttachment(TestData.dataAttachment)
        
        givenSdkWithHub(scope: scope)
    }
    
    private func assertPerThread(exceptionType: String, exceptionValue: String, exceptionMechanism: String, handled: Bool = true) throws {
        assertEventWithScopeCaptured { event, scope, _ in
            XCTAssertEqual(1, scope?.attachments.count)
            
            XCTAssertEqual(callStackTreePerThread.callStacks.count, event?.threads?.count)
            XCTAssertEqual(timeStampBegin, event?.timestamp)
            
            for callSack in callStackTreePerThread.callStacks {
                var flattenedRootFrames = callSack.flattenedRootFrames
                flattenedRootFrames.reverse()
                
                try! assertFrames(frames: flattenedRootFrames, event: event, exceptionType, exceptionValue, exceptionMechanism, handled: handled)
            }
        }
    }
    
    private func assertNothingCaptured() {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(0, client.captureEventWithScopeInvocations.count, "No events should be captured")
    }
    
    private func assertNotPerThread(exceptionType: String, exceptionValue: String, exceptionMechanism: String) throws {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        let invocations = client.captureEventWithScopeInvocations.invocations
        XCTAssertEqual(4, client.captureEventWithScopeInvocations.count, "Client expected to capture 2 events.")
        
        let firstEvent = invocations[0].event
        let secondEvent = invocations[1].event
        let thirdEvent = invocations[2].event
        let fourthEvent = invocations[3].event
        
        invocations.map { $0.event }.forEach {
            XCTAssertEqual(timeStampBegin, $0.timestamp)
            XCTAssertEqual(false, $0.threads?[0].crashed)
        }
        
        let allFrames = try XCTUnwrap(callStackTreeNotPerThread.callStacks.first?.flattenedRootFrames, "CallStackTree has no call stack.")
        
        // Overview of stacktrace
        // | frame 0 |
        //      | frame 1 |
        //          | frame 2 |
        //          | frame 3 |
        //              | frame 4 |
        //              | frame 5 |
        //              | frame 6 |     -> stack trace consists of [0,1,3,4,5,6]
        //          | frame 7 |
        //          | frame 8 |         -> stack trace consists of [0,1,2,3,7,8]
        //      | frame 9 |             -> stack trace consists of [0,1,9]
        // | frame 10 |
        //      | frame 11 |
        //          | frame 12 |
        //          | frame 13 |    -> stack trace consists of [10,11,12,13]
        
        let firstEventFrames = [0, 1, 2, 3, 4, 5, 6].map { allFrames[$0] }
        let secondEventFrames = [0, 1, 2, 3, 7, 8].map { allFrames[$0] }
        let thirdEventFrames = [0, 1, 9].map { allFrames[$0] }
        let fourthEventFrames = [10, 11, 12, 13].map { allFrames[$0] }
        
        try assertFrames(frames: firstEventFrames, event: firstEvent, exceptionType, exceptionValue, exceptionMechanism, debugMetaCount: 3)
        try assertFrames(frames: secondEventFrames, event: secondEvent, exceptionType, exceptionValue, exceptionMechanism, debugMetaCount: 3)
        try assertFrames(frames: thirdEventFrames, event: thirdEvent, exceptionType, exceptionValue, exceptionMechanism, debugMetaCount: 3)
        try assertFrames(frames: fourthEventFrames, event: fourthEvent, exceptionType, exceptionValue, exceptionMechanism, debugMetaCount: 3)
    }
    
    private func assertFrames(frames: [SentryMXFrame], event: Event?, _ exceptionType: String, _ exceptionValue: String, _ exceptionMechanism: String, handled: Bool = true, debugMetaCount: Int = 2) throws {
        let sentryFrames = try XCTUnwrap(event?.threads?.first?.stacktrace?.frames, "Event has no frames.")
        XCTAssertEqual(frames.count, sentryFrames.count)
        
        XCTAssertEqual(1, event?.exceptions?.count)
        let exception = try! XCTUnwrap(event?.exceptions?.first, "Event has exception.")
        XCTAssertEqual(frames.count, exception.stacktrace?.frames.count)
        
        let exceptionFrames = try! XCTUnwrap(exception.stacktrace?.frames, "Exception has no frames.")
    
        for i in 0..<frames.count {
            let mxFrame = frames[i]
            let sentryFrame = sentryFrames[i]
            let sentryExceptionFrame = exceptionFrames[i]
            assertFrame(mxFrame: mxFrame, sentryFrame: sentryFrame)
            assertFrame(mxFrame: mxFrame, sentryFrame: sentryExceptionFrame)
        }
        
        XCTAssertEqual(exceptionType, exception.type)
        XCTAssertEqual(exceptionValue, exception.value)
        XCTAssertEqual(exceptionMechanism, exception.mechanism?.type)
        XCTAssertEqual(handled, exception.mechanism?.handled?.boolValue)
        XCTAssertEqual(true, exception.mechanism?.synthetic)
        XCTAssertEqual(event?.threads?.first?.threadId, exception.threadId)
        
        XCTAssertEqual(debugMetaCount, event?.debugMeta?.count)
        guard let debugMeta = event?.debugMeta else {
            XCTFail("Event has no debugMeta.")
            return
        }
        
        XCTAssertEqual("macho", debugMeta[0].type)
        XCTAssertEqual("9E8D8DE6-EEC1-3199-8720-9ED68EE3F967", debugMeta[0].debugID)
        XCTAssertEqual("0x000000010109c000", debugMeta[0].imageAddress)
        XCTAssertEqual("Sentry", debugMeta[0].codeFile)
        
        XCTAssertEqual("macho", debugMeta[1].type)
        XCTAssertEqual("CA12CAFA-91BA-3E1C-BE9C-E34DB96FE7DF", debugMeta[1].debugID)
        XCTAssertEqual("0x0000000100f3c000", debugMeta[1].imageAddress)
        XCTAssertEqual("iOS-Swift", debugMeta[1].codeFile)
    }
    
    private func assertFrame(mxFrame: SentryMXFrame, sentryFrame: Frame) {
        XCTAssertEqual(mxFrame.binaryName, sentryFrame.package)
        
        let lastRootFrameAddress = formatHexAddress(value: mxFrame.address)
        XCTAssertEqual(lastRootFrameAddress, sentryFrame.instructionAddress)
        
        XCTAssertEqual(mxFrame.binaryName, sentryFrame.package)
        let lastRootFrameImageAddress = formatHexAddress(value: mxFrame.address - UInt64(mxFrame.offsetIntoBinaryTextSegment))
        XCTAssertEqual(lastRootFrameImageAddress, sentryFrame.imageAddress)
        
        XCTAssertFalse(sentryFrame.inApp as? Bool ?? true)
    }
  
}

@available(iOS 15, macOS 12, macCatalyst 15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXCallStackTree: MXCallStackTree {
    struct Override {
        var jsonRepresentation = Data()
    }
    
    public var overrides = Override()
    
    override func jsonRepresentation() -> Data {
        return overrides.jsonRepresentation
    }
}

@available(iOS 15, macOS 12, macCatalyst 15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXCrashDiagnostic: MXCrashDiagnostic {
    struct Override {
        var callStackTree = TestMXCallStackTree()
    }
    
    public var overrides = Override()
    
    override var callStackTree: MXCallStackTree {
        return overrides.callStackTree
    }
}

@available(iOS 15, macOS 12, macCatalyst 15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXCPUExceptionDiagnostic: MXCPUExceptionDiagnostic {
    struct Override {
        var callStackTree = TestMXCallStackTree()
    }
    
    public var overrides = Override()
    
    override var callStackTree: MXCallStackTree {
        return overrides.callStackTree
    }
    
    override var totalCPUTime: Measurement<UnitDuration> {
        return Measurement(value: 2.2, unit: .milliseconds)
    }
    
    override var totalSampledTime: Measurement<UnitDuration> {
        return Measurement(value: 5.5, unit: .milliseconds)
    }
}

@available(iOS 15, macOS 12, macCatalyst 15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXDiskWriteExceptionDiagnostic: MXDiskWriteExceptionDiagnostic {
    struct Override {
        var callStackTree = TestMXCallStackTree()
    }
    
    public var overrides = Override()
    
    override var callStackTree: MXCallStackTree {
        return overrides.callStackTree
    }
    
    override var totalWritesCaused: Measurement<UnitInformationStorage> {
        return Measurement(value: 5.5, unit: .mebibits)
    }
}

@available(iOS 15, macOS 12, macCatalyst 15, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXHangDiagnostic: MXHangDiagnostic {
    struct Override {
        var callStackTree = TestMXCallStackTree()
    }
    
    public var overrides = Override()
    
    override var callStackTree: MXCallStackTree {
        return overrides.callStackTree
    }
    
    override var hangDuration: Measurement<UnitDuration> {
        return Measurement(value: 6.6, unit: .seconds)
    }
}

#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
