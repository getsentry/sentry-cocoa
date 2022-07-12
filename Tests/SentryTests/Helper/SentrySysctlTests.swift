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
}
