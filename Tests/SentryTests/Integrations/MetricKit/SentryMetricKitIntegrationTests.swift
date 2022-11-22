import MetricKit
import Sentry
import XCTest

@available(iOS 14.0, macCatalyst 14.0, macOS 12.0, *)
final class SentryMetricKitIntegrationTests: SentrySDKIntegrationTestsBase {

    func testOptionEnabled_MetricKitManagerInitialized() {
        let sut = SentryMetricKitIntegration()
        
        let options = Options()
        options.enableMetricKit = true
        sut.install(with: options)
        
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
    
    func testPayloadReceived() throws {
        givenSdkWithHub()
        
        let sut = SentryMetricKitIntegration()
        
        let contents = try contentsOfResource("metric-kit-callstack-tree-simple")
        let callStackTree = try SentryMXCallStackTree.from(data: contents)
        
        Dynamic(sut).didReceiveCrashDiagnostic(MXCrashDiagnostic(), callStackTree: callStackTree)
        
        assertEventWithScopeCaptured { event, _, _ in
            XCTAssertNotNil(event)
            XCTAssertEqual(callStackTree.callStacks.count, event?.threads?.count)
            
            //TODO more assertions
        }
    }
}
