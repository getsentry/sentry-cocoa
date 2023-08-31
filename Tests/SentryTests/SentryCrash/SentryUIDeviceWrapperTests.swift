import SentryTestUtils
import XCTest

#if os(iOS)
class SentryUIDeviceWrapperTests: XCTestCase {
    func testExecutesLogicViaDispatchQueue() {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = dispatchQueue
        let sut = SentryUIDeviceWrapper()
        XCTAssertEqual(dispatchQueue.blockOnMainInvocations.count, 1)

        sut.stop()
        XCTAssertEqual(dispatchQueue.blockOnMainInvocations.count, 2)
    }
}
#endif
