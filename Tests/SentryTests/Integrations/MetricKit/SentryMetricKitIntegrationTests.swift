import Sentry
import XCTest

@available(iOS 14.0, macCatalyst 14.0, macOS 12.0, *)
final class SentryMetricKitIntegrationTests: XCTestCase {

    func testOptionEnabled_MetricKitManagerInitialized() {
        let sut = SentryMetricKitIntegration()
        
        let options = Options()
        options.enableMetricKit = true
        sut.install(with: options)
        
        XCTAssertNotNil(Dynamic(sut).metricKitManager as SentryMetricKitManager?)
    }
    
    func testOptionDisabled_MetricKitManagerNotInitialized() {
        let sut = SentryMetricKitIntegration()
        
        sut.install(with: Options())
        
        XCTAssertNil(Dynamic(sut).metricKitManager as SentryMetricKitManager?)
    }
    
    func testUninstall_MetricKitManagerSetToNil() {
        let sut = SentryMetricKitIntegration()
        
        let options = Options()
        options.enableMetricKit = true
        sut.install(with: options)
        sut.uninstall()
        
        XCTAssertNil(Dynamic(sut).metricKitManager as SentryMetricKitManager?)
    }
}
