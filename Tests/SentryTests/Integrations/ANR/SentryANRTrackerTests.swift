@_spi(Private) @testable import Sentry
import XCTest

final class SentryANRTrackerTests: XCTestCase {
    
    func testRemovesDeallocatedDelegates() throws {
        let helper = MockSentryANRTrackerHelper()
        let tracker = SentryANRTracker(helper: helper)
        var delegate: MockANRTrackerDelegate? = MockANRTrackerDelegate()
        weak var delegateWeak: MockANRTrackerDelegate? = delegate
        tracker.add(listener: try XCTUnwrap(delegate))
        
        delegate = nil
        XCTAssertNil(delegateWeak)
        tracker.add(listener: MockANRTrackerDelegate())
        XCTAssertEqual(1, tracker.mapping.count)
    }
    
}

final class MockSentryANRTrackerHelper: SentryANRTrackerInternalProtocol {
    func addListener(_ listender: any SentryANRTrackerInternalDelegate) {
    }
    
    func removeListener(_ listener: any SentryANRTrackerInternalDelegate) {
    }
    
    func clear() {
    }
    
}

final class MockANRTrackerDelegate: SentryANRTrackerDelegate {
    func anrDetected(type: Sentry.SentryANRType) {
    }
    
    func anrStopped(result: Sentry.SentryANRStoppedResult?) {
    }
}
