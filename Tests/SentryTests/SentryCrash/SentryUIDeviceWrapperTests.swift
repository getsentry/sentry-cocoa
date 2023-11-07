import SentryTestUtils
import XCTest

#if os(iOS)
class SentryUIDeviceWrapperTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        clearTestState()
    }
    
    func testExecutesLogicViaDispatchQueue() {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        SentryDependencyContainer.sharedInstance().dispatchQueueWrapper = dispatchQueue
        let sut = SentryUIDeviceWrapper()
        sut.start()
        XCTAssertEqual(dispatchQueue.blockOnMainInvocations.count, 1)

        sut.stop()
        XCTAssertEqual(dispatchQueue.blockOnMainInvocations.count, 2)
    }
}
#endif
