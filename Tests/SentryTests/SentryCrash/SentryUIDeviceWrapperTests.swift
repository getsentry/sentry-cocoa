@_spi(Private) import SentryTestUtils
@_spi(Private) @testable import Sentry
import XCTest

#if os(iOS)
class SentryUIDeviceWrapperTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        // swiftlint:disable:next avoid_clear_test_state - just disabled to allow adding the SwiftLint rule. Please double check if you can remove this when touching this.
        clearTestState()
    }
    
    func testExecutesLogicViaDispatchQueue() {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let sut = SentryDefaultUIDeviceWrapper(queueWrapper: dispatchQueue)
        sut.start()
        XCTAssertEqual(dispatchQueue.blockOnMainInvocations.count, 1)

        sut.stop()
        XCTAssertEqual(dispatchQueue.blockOnMainInvocations.count, 2)
    }
    
    func testGetsSystemVersion() {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let sut = SentryDefaultUIDeviceWrapper(queueWrapper: dispatchQueue)
        XCTAssertNotNil(sut.getSystemVersion())
    }
    
    func testBatteryLevel() {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let sut = SentryDefaultUIDeviceWrapper(queueWrapper: dispatchQueue)
        XCTAssertNotNil(sut.batteryLevel)
    }
    
    func testBatteryState() {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let sut = SentryDefaultUIDeviceWrapper(queueWrapper: dispatchQueue)
        XCTAssertNotNil(sut.batteryState)
    }

    func testCleansUp() {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        autoreleasepool {
            let sut = SentryDefaultUIDeviceWrapper(queueWrapper: dispatchQueue)
            sut.start()
            XCTAssertEqual(dispatchQueue.blockOnMainInvocations.count, 1)
        }
        XCTAssertEqual(dispatchQueue.blockOnMainInvocations.count, 2)
    }
    
    func testCurrentDevice() {
        let dispatchQueue = TestSentryDispatchQueueWrapper()
        let sut = SentryDefaultUIDeviceWrapper(queueWrapper: dispatchQueue)
        XCTAssertEqual(sut.currentDevice, UIDevice.current)
    }
}
#endif
