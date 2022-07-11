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
        let distance = Date().timeIntervalSince(sut.mainTimestamp)

        XCTAssertGreaterThan(distance, 0)
    }
    
    func testMainTimestamp_IsBiggerThan_ProcessStartTime() {
        let distance = sut.mainTimestamp.timeIntervalSince(sut.processStartTimestamp)

        XCTAssertGreaterThan(distance, 0)
    }
    
    func testMainTimestamp_IsBiggerThan_RuntimeInitTimestamp() {
        let distance = sut.mainTimestamp.timeIntervalSince(sut.runtimeInitTimestamp)

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
}
