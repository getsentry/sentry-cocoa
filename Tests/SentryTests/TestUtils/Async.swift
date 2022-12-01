import Foundation
import XCTest

func delayNonBlocking(timeout: Double = 0.2) {
    let group = DispatchGroup()
    group.enter()
    let queue = DispatchQueue(label: "delay", qos: .background, attributes: [])
    
    queue.asyncAfter(deadline: .now() + timeout) {
        group.leave()
    }
    
    group.wait()
}

extension DispatchGroup {
    
    /**
     * Waits for a default of 100 milliseconds and fails the test if the group didn't finish before the timeout.
     */
    func waitWithTimeout(timeout: Double = 100) {
        let result = self.wait(timeout: .now() + timeout)
        XCTAssertEqual(DispatchTimeoutResult.success, result)
    }
}
