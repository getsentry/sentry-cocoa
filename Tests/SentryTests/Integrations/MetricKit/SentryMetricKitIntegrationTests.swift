import Sentry
import SentryPrivate
import XCTest

#if os(iOS) || os(macOS)

/**
 * We need to check if MetricKit is available for compatibility on iOS 12 and below. As there are no compiler directives for iOS versions we use canImport.
 */
#if canImport(MetricKit)
import MetricKit
#endif

final class SentryMetricKitIntegrationTests: SentrySDKIntegrationTestsBase {
    
    var callStackTreePerThread: SentryMXCallStackTree!
    var callStackTreeNotPerThread: SentryMXCallStackTree!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        let contentsPerThread = try contentsOfResource("metric-kit-callstack-per-thread")
        callStackTreePerThread = try SentryMXCallStackTree.from(data: contentsPerThread)
        
        let contentsNotPerThread = try contentsOfResource("metric-kit-callstack-not-per-thread")
        callStackTreeNotPerThread = try SentryMXCallStackTree.from(data: contentsNotPerThread)
    }

    func testOptionEnabled_MetricKitManagerInitialized() {
        if #available(iOS 14, macOS 12, macCatalyst 14, *) {
            let sut = SentryMetricKitIntegration()
            
            givenInstalledWithEnabled(sut)
            
            XCTAssertNotNil(Dynamic(sut).metricKitManager as SentryMXManager?)
        }
    }
    
    func testOptionDisabled_MetricKitManagerNotInitialized() {
        if #available(iOS 14, macOS 12, macCatalyst 14, *) {
            let sut = SentryMetricKitIntegration()
            
            sut.install(with: Options())
            
            XCTAssertNil(Dynamic(sut).metricKitManager as SentryMXManager?)
        }
    }
    
    func testUninstall_MetricKitManagerSetToNil() {
        if #available(iOS 14, macOS 12, macCatalyst 14, *) {
            let sut = SentryMetricKitIntegration()
            
            let options = Options()
            options.enableMetricKit = true
            sut.install(with: options)
            sut.uninstall()
            
            XCTAssertNil(Dynamic(sut).metricKitManager as SentryMXManager?)
        }
    }
    
    func testMXCrashPayloadReceived() throws {
        if #available(iOS 14, macOS 12, macCatalyst 14, *) {
            givenSdkWithHub()
            let sut = SentryMetricKitIntegration()
            givenInstalledWithEnabled(sut)
            
            let mxDelegate = sut as SentryMXManagerDelegate
            mxDelegate.didReceiveCrashDiagnostic(MXCrashDiagnostic(), callStackTree: callStackTreePerThread, timeStampBegin: currentDate.date(), timeStampEnd: currentDate.date())
            
            try assertPerThread(exceptionType: "MXCrashDiagnostic", exceptionValue: "MachException Type:(null) Code:(null) Signal:(null)")
        }
    }
    
    func testCPUExceptionDiagnostic_PerThread() throws {
        if #available(iOS 14, macOS 12, macCatalyst 14, *) {
            givenSdkWithHub()
            
            let sut = SentryMetricKitIntegration()
            givenInstalledWithEnabled(sut)
            
            let mxDelegate = sut as SentryMXManagerDelegate
            mxDelegate.didReceiveCpuExceptionDiagnostic(TestMXCPUExceptionDiagnostic(), callStackTree: callStackTreePerThread, timeStampBegin: currentDate.date(), timeStampEnd: currentDate.date())
            
            try assertPerThread(exceptionType: "MXCPUException", exceptionValue: "MXCPUException totalCPUTime:2.2 ms totalSampledTime:5.5 ms")
        }
    }
    
    @available(iOS 15, macOS 12, *)
    func testCPUExceptionDiagnostic_NotPerThread() throws {
        givenSdkWithHub()
        
        let sut = SentryMetricKitIntegration()
        givenInstalledWithEnabled(sut)
        
        let mxDelegate = sut as SentryMXManagerDelegate
        mxDelegate.didReceiveCpuExceptionDiagnostic(TestMXCPUExceptionDiagnostic(), callStackTree: callStackTreeNotPerThread, timeStampBegin: currentDate.date(), timeStampEnd: currentDate.date())
        
        try assertNotPerThread(exceptionType: "MXCPUException", exceptionValue: "MXCPUException totalCPUTime:2.2 ms totalSampledTime:5.5 ms")
    }
    
    @available(iOS 15, macOS 12, *)
    func testDiskWriteExceptionDiagnostic() throws {
        givenSdkWithHub()
        
        let sut = SentryMetricKitIntegration()
        givenInstalledWithEnabled(sut)
        
        let mxDelegate = sut as SentryMXManagerDelegate
        mxDelegate.didReceiveDiskWriteExceptionDiagnostic(TestMXDiskWriteExceptionDiagnostic(), callStackTree: callStackTreeNotPerThread, timeStampBegin: currentDate.date(), timeStampEnd: currentDate.date())
        
        try assertNotPerThread(exceptionType: "MXDiskWriteException", exceptionValue: "MXDiskWriteException totalWritesCaused:5.5 Mib")
    }
    
    @available(iOS 14, macOS 12, macCatalyst 14, *)
    private func givenInstalledWithEnabled(_ integration: SentryMetricKitIntegration) {
        let options = Options()
        options.enableMetricKit = true
        integration.install(with: options)
    }
    
    private func assertPerThread(exceptionType: String, exceptionValue: String) throws {
        assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(callStackTreePerThread.callStacks.count, event?.threads?.count)
            
            for callSack in callStackTreePerThread.callStacks {
                var flattenedRootFrames = callSack.flattenedRootFrames
                flattenedRootFrames.reverse()
                
                try! assertFrames(frames: flattenedRootFrames, event: event, exceptionType, exceptionValue)
            }
        }
    }
    
    private func assertNotPerThread(exceptionType: String, exceptionValue: String) throws {
        guard let client = SentrySDK.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(2, client.captureEventWithScopeInvocations.count, "Client expected to capture 2 events.")
        let firstEvent = client.captureEventWithScopeInvocations.invocations[0].event
        let secondEvent = client.captureEventWithScopeInvocations.invocations[1].event
        
        XCTAssertEqual(false, firstEvent.threads?[0].crashed)
        XCTAssertEqual(false, secondEvent.threads?[0].crashed)
        
        let frames = try XCTUnwrap(callStackTreeNotPerThread.callStacks.first?.callStackRootFrames, "CallStackTree has no call stack.")
        
        try assertFrames(frames: frames[0].framesIncludingSelf, event: firstEvent, exceptionType, exceptionValue)
        try assertFrames(frames: frames[1].framesIncludingSelf, event: secondEvent, exceptionType, exceptionValue)
    }
    
    private func assertFrames(frames: [SentryMXFrame], event: Event?, _ exceptionType: String, _ exceptionValue: String) throws {
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
        XCTAssertEqual(event?.threads?.first?.threadId, exception.threadId)
        
        XCTAssertEqual(2, event?.debugMeta?.count)
        guard let debugMeta = event?.debugMeta else {
            XCTFail("Event has no debugMeta.")
            return
        }
        
        XCTAssertEqual("apple", debugMeta[0].type)
        XCTAssertEqual("9E8D8DE6-EEC1-3199-8720-9ED68EE3F967", debugMeta[0].uuid)
        XCTAssertEqual("0x000000010109c000", debugMeta[0].imageAddress)
        XCTAssertEqual("Sentry", debugMeta[0].name)
        
        XCTAssertEqual("apple", debugMeta[1].type)
        XCTAssertEqual("CA12CAFA-91BA-3E1C-BE9C-E34DB96FE7DF", debugMeta[1].uuid)
        XCTAssertEqual("0x0000000100f3c000", debugMeta[1].imageAddress)
        XCTAssertEqual("iOS-Swift", debugMeta[1].name)
    }
    
    private func assertFrame(mxFrame: SentryMXFrame, sentryFrame: Frame) {
        XCTAssertEqual(mxFrame.binaryName, sentryFrame.package)
        
        let lastRootFrameAddress = formatHexAddress(value: mxFrame.address)
        XCTAssertEqual(lastRootFrameAddress, sentryFrame.instructionAddress)
        
        XCTAssertEqual(mxFrame.binaryName, sentryFrame.package)
        let lastRootFrameImageAddress = formatHexAddress(value: mxFrame.address - UInt64(mxFrame.offsetIntoBinaryTextSegment))
        XCTAssertEqual(lastRootFrameImageAddress, sentryFrame.imageAddress)
    }
  
}

@available(iOS 14, macOS 12, macCatalyst 14, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXCPUExceptionDiagnostic: MXCPUExceptionDiagnostic {
    override var totalCPUTime: Measurement<UnitDuration> {
        return Measurement(value: 2.2, unit: .milliseconds)
    }
    
    override var totalSampledTime: Measurement<UnitDuration> {
        return Measurement(value: 5.5, unit: .milliseconds)
    }
}

@available(iOS 14, macOS 12, macCatalyst 14, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXDiskWriteExceptionDiagnostic: MXDiskWriteExceptionDiagnostic {
    override var totalWritesCaused: Measurement<UnitInformationStorage> {
        return Measurement(value: 5.5, unit: .mebibits)
    }
}

#endif
