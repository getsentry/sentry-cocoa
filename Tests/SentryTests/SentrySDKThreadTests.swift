@testable import Sentry
import XCTest

final class SentrySDKThreadTests: XCTestCase {
    func testRaceWhenBindingClient() {

        let options = Options()
        let sut = SentryHub(client: SentryClient(options: options), andScope: nil)

        for _ in 0..<100 {

            let exp = expectation(description: "wait")
            exp.expectedFulfillmentCount = 100

            let queue = DispatchQueue(label: "com.sentry.test_client", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])

            for _ in 0..<100 {
                queue.async {
                    sut.bindClient(SentryClient(options: options))
                    sut.capture(message: "Test message")
                    exp.fulfill()
                }
            }

            queue.activate()

            for _ in 0..<100 {
                sut.bindClient(nil)
            }

            wait(for: [exp], timeout: 1.0)
        }
    }
}
