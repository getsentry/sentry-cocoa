import Foundation
import XCTest

extension DispatchGroup {
    
    /**
     * Waits for a default of 100 milliseconds and fails the test if the group didn't finish before the timeout.
     */
    func waitWithTimeout(timeout: Double = 100) {
        let result = self.wait(timeout: .now() + timeout)
        XCTAssertEqual(DispatchTimeoutResult.success, result)
    }
}
