@_spi(Private) @testable import Sentry
import Darwin
import XCTest

class SentrySysctlTests: XCTestCase {
    
    private var sut: SentrySysctl!
    
    override func setUp() {
        super.setUp()
        sut = SentrySysctl()
    }

    func testSystemBootTimestamp_IsInThePast() {
        let distance = Date().timeIntervalSince(sut.systemBootTimestamp)

        XCTAssertGreaterThan(distance, 0)
    }

    func testProcessStartTimestamp_IsInThePast() {
        let distance = Date().timeIntervalSince(sut.processStartTimestamp)

        XCTAssertGreaterThan(distance, 0)
    }
    
    func testMainTimestamp_IsInThePast() {
        let distance = Date().timeIntervalSince(sut.moduleInitializationTimestamp)

        XCTAssertGreaterThan(distance, 0)
    }
    
    func testMainTimestamp_IsBiggerThan_ProcessStartTime() {
        let distance = sut.moduleInitializationTimestamp.timeIntervalSince(sut.processStartTimestamp)

        XCTAssertGreaterThan(distance, 0)
    }
    
    func testMainTimestamp_IsBiggerThan_RuntimeInitTimestamp() {
        let distance = sut.moduleInitializationTimestamp.timeIntervalSince(sut.runtimeInitTimestamp)

        XCTAssertGreaterThan(distance, 0)
    }
    
    func testRuntimeInitTimestamp_IsBiggerThan_ProcessStartTimestamp() {
        let distance = sut.runtimeInitTimestamp.timeIntervalSince(sut.processStartTimestamp)

        XCTAssertGreaterThan(distance, 0)
    }
    
    func testRuntimeInitTimestamp_IsInThePast() {
        let distance = Date().timeIntervalSince(sut.runtimeInitTimestamp)

        XCTAssertGreaterThan(distance, 0)
    }

    func testNeutralTimestampProviders() {
        let sut = SentrySysctlObjC(
            systemBootTimestampProvider: { 123 },
            processStartTimestampProvider: { 456 }
        )

        XCTAssertEqual(sut.systemBootTimestamp, Date(timeIntervalSince1970: 123))
        XCTAssertEqual(sut.processStartTimestamp, Date(timeIntervalSince1970: 456))
    }

    func testNeutralTimestampProviderErrorFallback() {
        let sut = SentrySysctlObjC(
            systemBootTimestampProvider: { 0 },
            processStartTimestampProvider: { 0 }
        )

        XCTAssertEqual(sut.systemBootTimestamp, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(sut.processStartTimestamp, Date(timeIntervalSince1970: 0))
    }

    func testDebuggerStatus_whenProcessIsTraced_shouldReturnTrue() {
        let sut = SentryDefaultDebuggerStatusProvider(processFlagsProvider: { P_TRACED })

        XCTAssertTrue(sut.isBeingTraced)
    }

    func testDebuggerStatus_whenProcessIsNotTraced_shouldReturnFalse() {
        let sut = SentryDefaultDebuggerStatusProvider(processFlagsProvider: { 0 })

        XCTAssertFalse(sut.isBeingTraced)
    }

    func testDebuggerStatus_whenTraceStateChanges_shouldReturnLatestState() {
        var processFlags: Int32 = 0
        let sut = SentryDefaultDebuggerStatusProvider(processFlagsProvider: { processFlags })

        XCTAssertFalse(sut.isBeingTraced)

        processFlags = P_TRACED

        XCTAssertTrue(sut.isBeingTraced)
    }

    func testDebuggerStatus_whenSysctlFails_shouldReturnFalse() {
        let sut = SentryDefaultDebuggerStatusProvider(processFlagsProvider: { nil })

        XCTAssertFalse(sut.isBeingTraced)
    }
}
