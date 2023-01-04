import XCTest

final class SentryMetricKitEventTests: XCTestCase {

    func testMXCPUException_IsMetricKitEvent() {
        XCTAssertTrue(TestData.metricKitEvent.isMetricKitEvent)
    }
    
    func testMXDiskWriteException_IsMetricKitEvent() {
        let event = Event(level: .warning)
        let exception = Exception(value: "something", type: "type")
        exception.mechanism = Mechanism(type: SentryMetricKitDiskWriteExceptionMechanism)
        event.exceptions = [exception]
        
        XCTAssertTrue(TestData.metricKitEvent.isMetricKitEvent)
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
}
