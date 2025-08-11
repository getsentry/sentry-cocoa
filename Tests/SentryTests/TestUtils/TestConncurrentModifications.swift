@_spi(Private) import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

extension XCTestCase {

    func testConcurrentModifications(asyncWorkItems: Int = 5, writeLoopCount: Int = 1_000, writeWork: @escaping (Int) -> Void, readWork: @escaping () -> Void = {}) {

        let queue = DispatchQueue(label: "testConcurrentModifications", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])

        let expectation = XCTestExpectation(description: "ConcurrentModifications")
        expectation.expectedFulfillmentCount = asyncWorkItems
        expectation.assertForOverFulfill = true

        for _ in 0..<asyncWorkItems {

            queue.async {

                for i in 0...writeLoopCount {
                    writeWork(i)
                }

                readWork()

                expectation.fulfill()
            }
        }

        queue.activate()

        self.wait(for: [expectation], timeout: 10)
    }
}
