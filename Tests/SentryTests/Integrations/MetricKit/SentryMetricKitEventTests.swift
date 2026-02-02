@_spi(Private) import Sentry
import XCTest

#if os(iOS) || os(macOS)

final class SentryMetricKitEventTests: XCTestCase {

    func testMXCPUException_IsMetricKitEvent() {
        XCTAssertTrue(TestData.metricKitEvent.isMetricKitEvent())
    }
    
    func testMXDiskWriteException_IsMetricKitEvent() {        
        XCTAssertTrue(createMetricKitEventWith(mechanismType: "mx_disk_write_exception").isMetricKitEvent())
    }
    
    func testMXHangDiagnostic_IsMetricKitEvent() {
        XCTAssertTrue(createMetricKitEventWith(mechanismType: "mx_hang_diagnostic").isMetricKitEvent())
    }
    
#if os(iOS) || os(tvOS) || os(visionOS)
    func testWatchDogEvent_IsNotMetricKitEvent() {
        XCTAssertFalse(TestData.oomEvent.isMetricKitEvent())
    }
#endif
    
    func testNormalEvent_IsNotMetricKitEvent() {
        XCTAssertFalse(TestData.event.isMetricKitEvent())
    }
    
    func testEmptyEvent_IsNotMetricKitEvent() {
        XCTAssertFalse(Event().isMetricKitEvent())
    }
    
    private func createMetricKitEventWith(mechanismType: String) -> Event {
        let event = Event(level: .warning)
        let exception = Exception(value: "something", type: "type")
        exception.mechanism = Mechanism(type: mechanismType)
        event.exceptions = [exception]
        
        return event
    }
}

#endif // os(iOS) || os(macOS)
