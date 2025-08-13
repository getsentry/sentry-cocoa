import Foundation
import XCTest

extension XCTest {
    func contentsOfResource(_ resource: String, ofType: String = "json") throws -> Data {
        let path = Bundle(for: type(of: self)).path(forResource: "Resources/\(resource)", ofType: "json")
        return try Data(contentsOf: URL(fileURLWithPath: path ?? ""))
    }
}

extension XCTestCase {

    func delayNonBlocking(timeout: Double = 0.2) {
        let expectation = XCTestExpectation(description: "Finish Delay")
        expectation.assertForOverFulfill = true

        let queue = DispatchQueue(label: "delay")

        queue.asyncAfter(deadline: .now() + timeout) {
            expectation.fulfill()
        }

        let timeoutWithBuffer = timeout * 1.3
        self.wait(for: [expectation], timeout: timeoutWithBuffer)
    }
}
