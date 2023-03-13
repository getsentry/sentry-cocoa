import SentryTestUtils
import XCTest

#if os(iOS)
class SentryUIDeviceWrapperTests: XCTestCase {
    func testExecutesLogicViaDispatchQueue() {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let sut = SentryUIDeviceWrapper(dispatchQueueWrapper: dispatchQueue)
        XCTAssertEqual(dispatchQueue.blockOnMainInvocations.count, 1)

        sut.stop()
        XCTAssertEqual(dispatchQueue.blockOnMainInvocations.count, 2)
    }
}
#endif
