import Foundation
import XCTest

/// Runs the test two times in a row and only fails the test if it fails twice.
///
/// - Parameter failAllowance: How often the test can fail.
/// - Parameter testRuns: The number of test runs.
func rerunFlakyTest(failAllowance: Int = 1, testRuns: Int = 2, closure: () throws -> Void) rethrows {
    
    var failedCount = 0
    
    let options = XCTExpectedFailure.Options()
    options.issueMatcher = { _ in
        failedCount += 1
        
        if failedCount > failAllowance {
            return false
        } else {
            return true
        }
    }
    options.isStrict = false
    
    for _ in 0..<testRuns {
        try XCTExpectFailure("", options: options) {
            try closure()
        }
    }
}
