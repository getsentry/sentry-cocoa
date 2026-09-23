#if !SDK_V10
@_spi(Private) @testable import Sentry
import XCTest

final class SentryANRTrackerTests: XCTestCase {
    
    func testAnrDetected_whenTypeProvided_shouldPreserveType() {
        // -- Arrange --
        let delegate = MockANRTrackerDelegate()
        let wrapper = DelegateWrapper(helper: delegate)
        let types: [SentryANRType] = [.fatalFullyBlocking, .fatalNonFullyBlocking, .fullyBlocking, .nonFullyBlocking, .unknown]

        // -- Act --
        for type in types {
            wrapper.anrDetected(type: type)
        }

        // -- Assert --
        XCTAssertEqual(delegate.detectedTypes, types)
    }

    func testAnrStopped_whenResultProvided_shouldPreserveDurations() throws {
        // -- Arrange --
        let delegate = MockANRTrackerDelegate()
        let wrapper = DelegateWrapper(helper: delegate)
        let result = SentryANRStoppedResult(minDuration: 1.25, maxDuration: 2.75)

        // -- Act --
        wrapper.anrStopped(result: result)

        // -- Assert --
        let receivedResult = try XCTUnwrap(XCTUnwrap(delegate.stoppedResults.first))
        XCTAssertTrue(receivedResult === result)
        XCTAssertEqual(receivedResult.minDuration, 1.25)
        XCTAssertEqual(receivedResult.maxDuration, 2.75)
    }

    func testAnrStopped_whenResultNil_shouldForwardNil() throws {
        // -- Arrange --
        let delegate = MockANRTrackerDelegate()
        let wrapper = DelegateWrapper(helper: delegate)

        // -- Act --
        wrapper.anrStopped(result: nil)

        // -- Assert --
        XCTAssertEqual(delegate.stoppedResults.count, 1)
        let receivedResult = try XCTUnwrap(delegate.stoppedResults.first)
        XCTAssertNil(receivedResult)
    }

    func testRemovesDeallocatedDelegates() throws {
        let helper = MockSentryANRTrackerHelper()
        let tracker = SentryANRTracker(helper: helper)
        var delegate: MockANRTrackerDelegate? = MockANRTrackerDelegate()

        tracker.add(listener: try XCTUnwrap(delegate))
        
        delegate = nil

        tracker.add(listener: MockANRTrackerDelegate())
        XCTAssertEqual(1, tracker.mapping.count)
    }
    
}

final class MockSentryANRTrackerHelper: SentryANRTrackerInternalProtocol {
    func addListener(_ listener: any SentryANRTrackerDelegate) {
    }
    
    func removeListener(_ listener: any SentryANRTrackerDelegate) {
    }
    
    func clear() {
    }
    
}

final class MockANRTrackerDelegate: SentryANRTrackerDelegate {
    var stoppedResults: [SentryANRStoppedResult?] = []
    var detectedTypes: [SentryANRType] = []

    func anrDetected(type: Sentry.SentryANRType) {
        detectedTypes.append(type)
    }
    
    func anrStopped(result: Sentry.SentryANRStoppedResult?) {
        stoppedResults.append(result)
    }
}
#endif
