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
    
    private var callStackTree: SentryMXCallStackTree!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        let contents = try contentsOfResource("metric-kit-callstack-tree-simple")
        callStackTree = try SentryMXCallStackTree.from(data: contents)
    }

    func testOptionEnabled_MetricKitManagerInitialized() {
        if #available(iOS 14, macOS 12, *) {
            let sut = SentryMetricKitIntegration()
            
            givenInstalledWithEnabled(sut)
            
            XCTAssertNotNil(Dynamic(sut).metricKitManager as SentryMXManager?)
        }
    }
    
    func testOptionDisabled_MetricKitManagerNotInitialized() {
        if #available(iOS 14, macOS 12, *) {
            let sut = SentryMetricKitIntegration()
            
            sut.install(with: Options())
            
            XCTAssertNil(Dynamic(sut).metricKitManager as SentryMXManager?)
        }
    }
    
    func testUninstall_MetricKitManagerSetToNil() {
        if #available(iOS 14, macOS 12, *) {
            let sut = SentryMetricKitIntegration()
            
            let options = Options()
            options.enableMetricKit = true
            sut.install(with: options)
            sut.uninstall()
            
            XCTAssertNil(Dynamic(sut).metricKitManager as SentryMXManager?)
        }
    }
    
    func testMXCrashPayloadReceived() throws {
        if #available(iOS 14, macOS 12, *) {
            givenSdkWithHub()
            let sut = SentryMetricKitIntegration()
            givenInstalledWithEnabled(sut)
            
            Dynamic(sut).didReceiveCrashDiagnostic(MXCrashDiagnostic(), callStackTree: callStackTree, timeStampBegin: currentDate.date(), timeStampEnd: currentDate.date())
            
            assertMXEvent(exceptionType: "MXCrashDiagnostic", exceptionValue: "MachException Type:(null) Code:(null) Signal:(null)")
        }
    }
    
    func testCPUExceptionDiagnostic() throws {
        if #available(iOS 14, macOS 12, *) {
            givenSdkWithHub()
            
            let sut = SentryMetricKitIntegration()
            givenInstalledWithEnabled(sut)
            
            Dynamic(sut).didReceiveCpuExceptionDiagnostic(TestMXCPUExceptionDiagnostic(), callStackTree: callStackTree, timeStampBegin: currentDate.date(), timeStampEnd: currentDate.date())
            
            assertMXEvent(exceptionType: "MXCPUException", exceptionValue: "MXCPUException totalCPUTime:2.2 ms totalSampledTime:5.5 ms")
        }
    }
    
    func testDiskWriteExceptionDiagnostic() throws {
        if #available(iOS 14, macOS 12, *) {
            givenSdkWithHub()
            
            let sut = SentryMetricKitIntegration()
            givenInstalledWithEnabled(sut)
            
            Dynamic(sut).didReceiveDiskWriteExceptionDiagnostic(TestMXDiskWriteExceptionDiagnostic(), callStackTree: callStackTree, timeStampBegin: currentDate.date(), timeStampEnd: currentDate.date())
            
            assertMXEvent(exceptionType: "MXDiskWriteException", exceptionValue: "MXDiskWriteException totalWritesCaused:5.5 Mib")
        }
    }
    
    @available(iOS 14, macOS 12, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    private func givenInstalledWithEnabled(_ integration: SentryMetricKitIntegration) {
        let options = Options()
        options.enableMetricKit = true
        integration.install(with: options)
    }
    
    @available(iOS 14, macOS 12, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    private func assertMXEvent(exceptionType: String, exceptionValue: String) {
        assertEventWithScopeCaptured { event, _, _ in
            XCTAssertEqual(callStackTree.callStacks.count, event?.threads?.count)
            
            guard var flattenedRootFrames = callStackTree.callStacks.first?.flattenedRootFrames else {
                XCTFail("CallStackTree has no call stack.")
                return
            }
            flattenedRootFrames.reverse()
            
            guard let sentryFrames = event?.threads?.first?.stacktrace?.frames else {
                XCTFail("Event has no frames.")
                return
            }
            XCTAssertEqual(flattenedRootFrames.count, sentryFrames.count)
            
            for i in 0..<flattenedRootFrames.count {
                let mxFrame = flattenedRootFrames[i]
                let sentryFrame = sentryFrames[i]
                assertFrame(mxFrame: mxFrame, sentryFrame: sentryFrame)
            }
            
            XCTAssertEqual(1, event?.exceptions?.count)
            let exception = event?.exceptions?.first
            
            XCTAssertEqual(exceptionType, exception?.type)
            XCTAssertEqual(exceptionValue, exception?.value)
        }
    }
    
    @available(iOS 14, macOS 12, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    private func assertFrame(mxFrame: SentryMXFrame, sentryFrame: Frame) {
        XCTAssertEqual(mxFrame.binaryName, sentryFrame.package)
        
        let lastRootFrameAddress = formatHexAddress(value: mxFrame.address)
        XCTAssertEqual(lastRootFrameAddress, sentryFrame.instructionAddress)
        
        XCTAssertEqual(mxFrame.binaryName, sentryFrame.package)
        let lastRootFrameImageAddress = formatHexAddress(value: mxFrame.address - UInt64(mxFrame.offsetIntoBinaryTextSegment))
        XCTAssertEqual(lastRootFrameImageAddress, sentryFrame.imageAddress)
    }
}

@available(iOS 14, macOS 12, *)
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

@available(iOS 14, macOS 12, *)
@available(tvOS, unavailable)
@available(watchOS, unavailable)
class TestMXDiskWriteExceptionDiagnostic: MXDiskWriteExceptionDiagnostic {
    override var totalWritesCaused: Measurement<UnitInformationStorage> {
        return Measurement(value: 5.5, unit: .mebibits)
    }
}

#endif
