import Sentry
import SentryPrivate
import XCTest

#if os(iOS) || os(macOS)

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
        assertEventWithScopeCaptured { e, _, _ in
            let event = try! XCTUnwrap(e)
            XCTAssertEqual(callStackTree.callStacks.count, event.threads?.count)
            
            XCTAssertEqual(1, event.exceptions?.count)
            let exception = try! XCTUnwrap(event.exceptions?.first)
            
            XCTAssertEqual(exceptionType, exception.type)
            XCTAssertEqual(exceptionValue, exception.value)
        }
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
