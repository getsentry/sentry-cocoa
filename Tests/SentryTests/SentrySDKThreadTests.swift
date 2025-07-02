@testable import Sentry
import XCTest

final class SentrySDKThreadTests: XCTestCase {
    func testRaceWhenBindingClient() {
        for _ in 0..<10_000 {
            SentrySDK.start(options: .init())
            let exp = expectation(description: "wait")
            let warmupExpectation = expectation(description: "warmup")
            let warmupCount = 100
            warmupExpectation.expectedFulfillmentCount = warmupCount
            let queue = DispatchQueue(label: "com.sentry.test_client", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
            for i in 0..<1_000 {
                exp.expectedFulfillmentCount += 1
                queue.async {
                    SentrySDK.currentHub().capture(event: .init())
                    exp.fulfill()
                    if i < warmupCount {
                        warmupExpectation.fulfill()
                    }
                }
            }
            exp.expectedFulfillmentCount -= 1
            
            queue.activate()
            
            wait(for: [warmupExpectation])
            SentrySDK.currentHub().bindClient(nil)
            
            wait(for: [exp])
        }
    }
}
