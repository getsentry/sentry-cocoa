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
}
