import SentryTestUtils
import XCTest

final class SentryMetricKitEventTests: XCTestCase {

    func testMXCPUException_IsMetricKitEvent() {
        XCTAssertTrue(TestData.metricKitEvent.isMetricKitEvent)
    }
    
    func testMXDiskWriteException_IsMetricKitEvent() {        
        XCTAssertTrue(createMetricKitEventWith(mechanismType: SentryMetricKitDiskWriteExceptionMechanism).isMetricKitEvent)
    }
    
    func testMXHangDiagnostic_IsMetricKitEvent() {
        XCTAssertTrue(createMetricKitEventWith(mechanismType: SentryMetricKitHangDiagnosticMechanism).isMetricKitEvent)
    }
    
    func testWatchDogEvent_IsNotMetricKitEvent() {
        XCTAssertFalse(TestData.oomEvent.isMetricKitEvent)
    }
    
    func testNormalEvent_IsNotMetricKitEvent() {
        XCTAssertFalse(TestData.event.isMetricKitEvent)
    }
    
    func testEmptyEvent_IsNotMetricKitEvent() {
        XCTAssertFalse(Event().isMetricKitEvent)
    }
    
    private func createMetricKitEventWith(mechanismType: String) -> Event {
        let event = Event(level: .warning)
        let exception = Exception(value: "something", type: "type")
        exception.mechanism = Mechanism(type: mechanismType)
        event.exceptions = [exception]
        
        return event
    }
}
