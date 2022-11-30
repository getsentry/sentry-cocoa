import MetricKit
import Sentry
import XCTest

@available(iOS 14.0, macCatalyst 14.0, macOS 12.0, *)
final class SentryMetricKitIntegrationTests: SentrySDKIntegrationTestsBase {

    func testOptionEnabled_MetricKitManagerInitialized() {
        let sut = SentryMetricKitIntegration()
        
        givenInstalledWithEnabled(sut)
        
        XCTAssertNotNil(Dynamic(sut).metricKitManager as SentryMXManager?)
    }
    
    func testOptionDisabled_MetricKitManagerNotInitialized() {
        let sut = SentryMetricKitIntegration()
        
        sut.install(with: Options())
        
        XCTAssertNil(Dynamic(sut).metricKitManager as SentryMXManager?)
    }
    
    func testUninstall_MetricKitManagerSetToNil() {
        let sut = SentryMetricKitIntegration()
        
        let options = Options()
        options.enableMetricKit = true
        sut.install(with: options)
        sut.uninstall()
        
        XCTAssertNil(Dynamic(sut).metricKitManager as SentryMXManager?)
    }
    
    func testMXCrashPayloadReceived() throws {
        givenSdkWithHub()
        
        let sut = SentryMetricKitIntegration()
        
        let contents = try contentsOfResource("metric-kit-callstack-tree-simple")
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        
        Dynamic(sut).didReceiveCrashDiagnostic(MXCrashDiagnostic(), callStackTree: callStackTree, timeStampBegin: currentDate.date(), timeStampEnd: currentDate.date())
        
        assertEventWithScopeCaptured { e, _, _ in
            let event = try! XCTUnwrap(e)
            XCTAssertEqual(callStackTree.callStacks.count, event.threads?.count)
            
            XCTAssertEqual(1, event.exceptions?.count)
            let exception = try! XCTUnwrap(event.exceptions?.first)
            
            XCTAssertEqual("MXCrashDiagnostic", exception.type)
            XCTAssertEqual("MachException Type:(null) Code:(null) Signal:(null)", exception.value)
        }
    }
    
    func testCPUExceptionDiagnostic() throws {
        givenSdkWithHub()
        
        let sut = SentryMetricKitIntegration()
        givenInstalledWithEnabled(sut)
        
        let contents = try contentsOfResource("metric-kit-callstack-tree-simple")
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        
        Dynamic(sut).didReceiveCpuExceptionDiagnostic(TestMXCPUExceptionDiagnostic(), callStackTree: callStackTree, timeStampBegin: currentDate.date(), timeStampEnd: currentDate.date())
        
        assertEventWithScopeCaptured { e, _, _ in
            let event = try! XCTUnwrap(e)
            XCTAssertEqual(callStackTree.callStacks.count, event.threads?.count)
            
            XCTAssertEqual(1, event.exceptions?.count)
            let exception = try! XCTUnwrap(event.exceptions?.first)
            
            XCTAssertEqual("MXCPUException", exception.type)
            XCTAssertEqual("MXCPUException totalCPUTime:2 ms totalSampledTime:5 ms", exception.value)
        }
    }
    
    private func givenInstalledWithEnabled(_ integration: SentryMetricKitIntegration) {
        let options = Options()
        options.enableMetricKit = true
        integration.install(with: options)
    }
}

@available(iOS 14.0, macCatalyst 14.0, macOS 12.0, *)
class TestMXCPUExceptionDiagnostic: MXCPUExceptionDiagnostic {
    override var totalCPUTime: Measurement<UnitDuration> {
        return Measurement(value: 2.0, unit: .milliseconds)
    }
    
    override var totalSampledTime: Measurement<UnitDuration> {
        return Measurement(value: 5.0, unit: .milliseconds)
    }
}
