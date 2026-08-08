@testable import Sentry
import XCTest

final class SentryOptionsFeatureFlagsUsageTests: XCTestCase {

    func testFeatureFlagsUsed_whenInitialized_shouldBeFalse() {
        XCTAssertFalse(Options().featureFlagsUsed)
    }

    func testMarkFeatureFlagsUsed_whenCalled_shouldSetFeatureFlagsUsed() {
        let sut = Options()

        sut.markFeatureFlagsUsed()

        XCTAssertTrue(sut.featureFlagsUsed)
    }

    func testFeatureFlagsUsed_whenReadAndWrittenConcurrently_shouldRemainTrue() {
        let sut = Options()
        let queue = DispatchQueue(label: "SentryOptionsFeatureFlagsUsageTests", attributes: .concurrent)
        let completed = expectation(description: "Concurrent feature flag usage access completed")
        completed.expectedFulfillmentCount = 200
        completed.assertForOverFulfill = true

        for _ in 0..<100 {
            queue.async {
                sut.markFeatureFlagsUsed()
                completed.fulfill()
            }
            queue.async {
                _ = sut.featureFlagsUsed
                completed.fulfill()
            }
        }

        wait(for: [completed], timeout: 5)
        XCTAssertTrue(sut.featureFlagsUsed)
    }
}
