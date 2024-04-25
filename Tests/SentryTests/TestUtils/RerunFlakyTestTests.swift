import Nimble
import XCTest

final class RerunFlakyTestTest: XCTestCase {

    func testAllSucceed_TestSucceeds() {
        rerunFlakyTest {
            expect(true) == true
        }
    }
    
    func testAllFail_TestMustFail() {
        XCTExpectFailure("This test must fail because all test runs fail.")
        
        rerunFlakyTest {
            expect(false) == true
        }
    }
    
    func testOneFail_TestSucceeds() {
        var count = 0
        
        rerunFlakyTest {
            expect(count) != 0
            count += 1
        }
    }
    
    func testFailAllowance_TestSucceeds() {
        var count = 0
        
        rerunFlakyTest(failAllowance: 2, testRuns: 5) {
            expect(count) > 1
            count += 1
        }
    }
    
    func testFailAllowance_TestMustFail() {
        XCTExpectFailure("This test must fail because the failures exceed failAllowance.")
        
        var count = 0
        
        rerunFlakyTest(failAllowance: 2, testRuns: 5) {
            expect(count) > 2
            count += 1
        }
    }
}
