import XCTest

final class SentryCrashDoctorTests: XCTestCase {

    func testBadAccess() throws {
        let report = try getCrashReport(resource: "Resources/crash-bad-access")
        
        let diagnose = SentryCrashDoctor().diagnoseCrash(report)
        
        XCTAssertEqual("EXC_ARM_DA_ALIGN at 0x13fd4582e.", diagnose)
    }
    
    func testBadAccess_NoSubcode() throws {
        let report = try getCrashReport(resource: "Resources/crash-bad-access-no-subcode")
        
        let diagnose = SentryCrashDoctor().diagnoseCrash(report)
        
        XCTAssertEqual("Attempted to dereference garbage pointer at 0x13fd4582e.", diagnose)
    }
}
