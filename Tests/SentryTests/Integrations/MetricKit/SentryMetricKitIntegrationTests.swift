@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

/**
 * We need to check if MetricKit is available for compatibility on iOS 12 and below. As there are no compiler directives for iOS versions we use canImport.
 */
#if canImport(MetricKit)
import MetricKit
#endif // canImport(MetricKit)

@available(macOS 12.0, *)
final class SentryMetricKitIntegrationTests: SentrySDKIntegrationTestsBase {
    
    var callStackTreePerThread: SentryMXCallStackTree!
    var callStackTreeNotPerThread: SentryMXCallStackTree!
    var timeStampBegin: Date!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        let contentsPerThread = try contentsOfResource("MetricKitCallstacks/per-thread")
        callStackTreePerThread = try SentryMXCallStackTree.from(data: contentsPerThread)
        
        let contentsNotPerThread = try contentsOfResource("MetricKitCallstacks/not-per-thread")
        callStackTreeNotPerThread = try SentryMXCallStackTree.from(data: contentsNotPerThread)
        
        timeStampBegin = SentryDependencyContainer.sharedInstance().dateProvider.date().addingTimeInterval(21.23)
    }
    
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }

    func testOptionEnabled_MetricKitManagerInitialized() {
          let options = Options()
          options.enableMetricKit = true
          let sut = SentryMetricKitIntegration(with: options, dependencies: ())
          XCTAssertNotNil(sut)
    }
    
    func testOptionDisabled_MetricKitManagerNotInitialized() {
          let options = Options()
          let sut = SentryMetricKitIntegration(with: options, dependencies: ())
          XCTAssertNil(sut)
    }
    
    func testUninstall_MetricKitManagerSetToNil() {
            
            let options = Options()
            options.enableMetricKit = true
            let sut = SentryMetricKitIntegration(with: options, dependencies: ())
            sut?.uninstall()
            
            XCTAssertNil((Dynamic(sut).metricKitManager as SentryMXManager?)?.delegate)
    }
    
    func testMXCrashPayloadReceived() throws {
            givenSDKWithHubWithScope()
            
        let options = Options()
        options.enableMetricKit = true
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))
            
        sut.didReceiveCrashDiagnostic(MXCrashDiagnostic(), callStackTree: callStackTreePerThread, timeStampBegin: timeStampBegin)
            
        try assertPerThread(exceptionType: "MXCrashDiagnostic", exceptionValue: "MachException Type:(null) Code:(null) Signal:(null)", exceptionMechanism: "MXCrashDiagnostic", handled: false)
    }
    
    func testAttachDiagnosticAsAttachment() throws {
            givenSDKWithHubWithScope()
            
        let options = Options()
        options.enableMetricKit = true
        options.enableMetricKitRawPayload = true
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))
            
            let diagnostic = MXCrashDiagnostic()
        sut.didReceiveCrashDiagnostic(diagnostic, callStackTree: callStackTreePerThread, timeStampBegin: timeStampBegin)
            
            try assertEventWithScopeCaptured { _, scope, _ in
                let diagnosticAttachment = scope?.attachments.first { $0.filename == "MXDiagnosticPayload.json" }
                
                XCTAssertEqual(diagnosticAttachment?.data, diagnostic.jsonRepresentation())
            }
    }
    
    func testDontAttachDiagnosticAsAttachment() throws {
            givenSDKWithHubWithScope()
            
        let options = Options()
        options.enableMetricKit = true
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))
            
            let diagnostic = MXCrashDiagnostic()
        sut.didReceiveCrashDiagnostic(diagnostic, callStackTree: callStackTreePerThread, timeStampBegin: timeStampBegin)
            
            try assertEventWithScopeCaptured { _, scope, _ in
                let diagnosticAttachment = scope?.attachments.first { $0.filename == "MXDiagnosticPayload.json" }
                
                XCTAssertNil(diagnosticAttachment)
            }
    }
    
    func testSetInAppIncludes_AppliesInAppToStackTrace() throws {
            givenSDKWithHubWithScope()
            
        let options = Options()
        options.enableMetricKit = true
        options.add(inAppInclude: "iOS-Swift")
        let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))
            
            sut.didReceiveCrashDiagnostic(MXCrashDiagnostic(), callStackTree: callStackTreePerThread, timeStampBegin: timeStampBegin)
            
            try assertEventWithScopeCaptured { event, _, _ in
                let stacktrace = try XCTUnwrap( event?.threads?.first?.stacktrace)
                
                let inAppFramesCount = stacktrace.frames.filter { $0.inApp as? Bool ?? false }.count
                
                XCTAssertEqual(2, inAppFramesCount)
            }
    }
    
    func testCPUExceptionDiagnostic_PerThread() throws {
            givenSDKWithHubWithScope()
            
            let options = Options()
            options.enableMetricKit = true
            let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))
            
            sut.didReceiveCpuExceptionDiagnostic(TestMXCPUExceptionDiagnostic(), callStackTree: callStackTreePerThread, timeStampBegin: timeStampBegin)
            
            assertNothingCaptured()
    }
    
    func testCPUExceptionDiagnostic_NotPerThread() throws {
            givenSDKWithHubWithScope()
            
            let options = Options()
            options.enableMetricKit = true
            let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))
            
            sut.didReceiveCpuExceptionDiagnostic(TestMXCPUExceptionDiagnostic(), callStackTree: callStackTreeNotPerThread, timeStampBegin: timeStampBegin)
            
            try assertNotPerThread(exceptionType: "MXCPUException", exceptionValue: "MXCPUException totalCPUTime:2.2 ms totalSampledTime:5.5 ms", exceptionMechanism: "mx_cpu_exception")
    }
    
    func testCPUExceptionDiagnostic_OnlyOneFrame() throws {
            givenSDKWithHubWithScope()
            
            let options = Options()
            options.enableMetricKit = true
            let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))
            
            let contents = try contentsOfResource("MetricKitCallstacks/not-per-thread-only-one-frame")
            let callStackTree = try SentryMXCallStackTree.from(data: contents)
            
            sut.didReceiveCpuExceptionDiagnostic(TestMXCPUExceptionDiagnostic(), callStackTree: callStackTree, timeStampBegin: timeStampBegin)
            
            guard let client = SentrySDKInternal.currentHub().getClient() as? TestClient else {
                XCTFail("Hub Client is not a `TestClient`")
                return
            }
            
            let invocations = client.captureEventWithScopeInvocations.invocations
            XCTAssertEqual(1, client.captureEventWithScopeInvocations.count)
            
            try assertEvent(event: try XCTUnwrap(invocations.first).event)
            
            func assertEvent(event: Event) throws {
                let sentryFrames = try XCTUnwrap(event.threads?.first?.stacktrace?.frames, "Event has no frames.")
                
                XCTAssertEqual(1, sentryFrames.count)
                let frame = sentryFrames.first
                XCTAssertEqual("0x000000021f1a0001", frame?.imageAddress)
                XCTAssertEqual("libsystem_pthread.dylib", frame?.package)
                XCTAssertFalse(frame?.inApp?.boolValue ?? true)
            }
    }
    
    func testDiskWriteExceptionDiagnostic() throws {
            givenSDKWithHubWithScope()
            
            let options = Options()
            options.enableMetricKit = true
            let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))
            
            sut.didReceiveDiskWriteExceptionDiagnostic(TestMXDiskWriteExceptionDiagnostic(), callStackTree: callStackTreeNotPerThread, timeStampBegin: timeStampBegin)
            
            try assertNotPerThread(exceptionType: "MXDiskWriteException", exceptionValue: "MXDiskWriteException totalWritesCaused:5.5 Mib", exceptionMechanism: "mx_disk_write_exception")
    }
    
    func testHangDiagnostic() throws {
            givenSDKWithHubWithScope()
            
            let options = Options()
            options.enableMetricKit = true
            let sut = try XCTUnwrap(SentryMetricKitIntegration(with: options, dependencies: ()))
            
            sut.didReceiveHangDiagnostic(TestMXHangDiagnostic(), callStackTree: callStackTreeNotPerThread, timeStampBegin: timeStampBegin)
            
            try assertNotPerThread(exceptionType: "MXHangDiagnostic", exceptionValue: "MXHangDiagnostic hangDuration:6.6 sec", exceptionMechanism: "mx_hang_diagnostic")
    }
    
    private func givenSDKWithHubWithScope() {
        let scope = Scope()
        scope.addBreadcrumb(TestData.crumb)
        scope.addAttachment(TestData.dataAttachment)
        
        givenSdkWithHub(scope: scope)
    }
    
    private func assertPerThread(exceptionType: String, exceptionValue: String, exceptionMechanism: String, handled: Bool = true) throws {
        try assertEventWithScopeCaptured { event, scope, _ in
            XCTAssertEqual(1, scope?.attachments.count)
            
            XCTAssertEqual(callStackTreePerThread.callStacks.count, event?.threads?.count)
            XCTAssertEqual(timeStampBegin, event?.timestamp)
            
            try assertFrames(event: event, exceptionType, exceptionValue, exceptionMechanism, framesCount: 3, handled: handled)
        }
    }
    
    private func assertNothingCaptured() {
        guard let client = SentrySDKInternal.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        XCTAssertEqual(0, client.captureEventWithScopeInvocations.count, "No events should be captured")
    }
    
    private func assertNotPerThread(exceptionType: String, exceptionValue: String, exceptionMechanism: String) throws {
        guard let client = SentrySDKInternal.currentHub().getClient() as? TestClient else {
            XCTFail("Hub Client is not a `TestClient`")
            return
        }
        
        let invocations = client.captureEventWithScopeInvocations.invocations
        XCTAssertEqual(1, invocations.count, "Client expected to capture 1 event.")
    }
    
    private func assertFrames(event: Event?, _ exceptionType: String, _ exceptionValue: String, _ exceptionMechanism: String, framesCount: Int, handled: Bool = true, debugMetaCount: Int = 2) throws {
        let sentryFrames = try XCTUnwrap(event?.threads?.first?.stacktrace?.frames, "Event has no frames.")
        XCTAssertEqual(framesCount, sentryFrames.count)
        
        XCTAssertEqual(1, event?.exceptions?.count)
        let exception = try XCTUnwrap(event?.exceptions?.first, "Event has exception.")

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
        
        XCTAssertEqual("macho", try XCTUnwrap(debugMeta.first).type)
        XCTAssertEqual("9E8D8DE6-EEC1-3199-8720-9ED68EE3F967", try XCTUnwrap(debugMeta.first).debugID)
        XCTAssertEqual("0x000000010109c000", try XCTUnwrap(debugMeta.first).imageAddress)
        XCTAssertEqual("Sentry", try XCTUnwrap(debugMeta.first).codeFile)
        
        XCTAssertEqual("macho", try XCTUnwrap(debugMeta.element(at: 1)).type)
        XCTAssertEqual("CA12CAFA-91BA-3E1C-BE9C-E34DB96FE7DF", try XCTUnwrap(debugMeta.element(at: 1)).debugID)
        XCTAssertEqual("0x0000000100f3c000", try XCTUnwrap(debugMeta.element(at: 1)).imageAddress)
        XCTAssertEqual("iOS-Swift", try XCTUnwrap(debugMeta.element(at: 1)).codeFile)
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

@available(tvOS, unavailable)
@available(watchOS, unavailable)
@available(macOS 12.0, *)
class TestMXCallStackTree: MXCallStackTree {
    struct Override {
        var jsonRepresentation = Data()
    }
    
    public var overrides = Override()
    
    override func jsonRepresentation() -> Data {
        return overrides.jsonRepresentation
    }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
@available(macOS 12.0, *)
class TestMXCrashDiagnostic: MXCrashDiagnostic {
    struct Override {
        var callStackTree = TestMXCallStackTree()
    }
    
    public var overrides = Override()
    
    override var callStackTree: MXCallStackTree {
        return overrides.callStackTree
    }
}

@available(tvOS, unavailable)
@available(watchOS, unavailable)
@available(macOS 12.0, *)
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

@available(tvOS, unavailable)
@available(watchOS, unavailable)
@available(macOS 12.0, *)
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

@available(tvOS, unavailable)
@available(watchOS, unavailable)
@available(macOS 12.0, *)
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
