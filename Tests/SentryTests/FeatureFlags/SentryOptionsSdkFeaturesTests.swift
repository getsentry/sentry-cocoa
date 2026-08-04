@testable import Sentry
import XCTest

final class SentryOptionsSdkFeaturesTests: XCTestCase {

    func testAddSdkFeature_whenRepeated_shouldDeduplicateFeature() {
        let sut = Options()

        sut.addSdkFeature("featureFlags")
        sut.addSdkFeature("featureFlags")

        XCTAssertEqual(sut.sdkFeatures, ["featureFlags"])
    }

    func testSdkFeatures_whenMultipleAdded_shouldReturnDeterministicOrder() {
        let sut = Options()

        sut.addSdkFeature("zebra")
        sut.addSdkFeature("alpha")

        XCTAssertEqual(sut.sdkFeatures, ["alpha", "zebra"])
    }

    func testSdkFeatures_whenReadAndWrittenConcurrently_shouldRemainConsistent() {
        let sut = Options()
        let queue = DispatchQueue(label: "SentryOptionsSdkFeaturesTests", attributes: .concurrent)
        let completed = expectation(description: "Concurrent feature access completed")
        completed.expectedFulfillmentCount = 200
        completed.assertForOverFulfill = true

        for index in 0..<100 {
            queue.async {
                sut.addSdkFeature("feature-\(index)")
                completed.fulfill()
            }
            queue.async {
                _ = sut.sdkFeatures
                completed.fulfill()
            }
        }

        wait(for: [completed], timeout: 5)
        XCTAssertEqual(sut.sdkFeatures.count, 100)
    }
}
