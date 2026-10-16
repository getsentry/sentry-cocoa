@_spi(Private) import SentryTestUtils
#if SWIFT_PACKAGE
#if canImport(UIKit)
import UIKit
#endif
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import XCTest

#if os(iOS) || os(tvOS)
final class SentryApplicationExtensionsTests: XCTestCase {

    /// `-[UIApplication applicationState]` must only be read on the main thread. This exercises the real
    /// `UIApplication` accessor from a background queue so the Main Thread Checker flags a regression that
    /// reads the state inline instead of hopping to the main queue.
    func testUnsafeApplicationState_whenCalledOffMainThread_shouldReturnState() throws {
        // -- Arrange --
        let application = UIApplication.shared
        let readExpectation = expectation(description: "unsafeApplicationState read off the main thread")
        let result = SentryMutex<UIApplication.State?>(nil)

        // -- Act --
        DispatchQueue.global().async {
            XCTAssertFalse(Thread.isMainThread)
            result.withLock { $0 = application.unsafeApplicationState }
            readExpectation.fulfill()
        }
        // Waiting spins the main run loop so the accessor's main queue hop can run.
        wait(for: [readExpectation], timeout: 5)

        // -- Assert --
        let state = try XCTUnwrap(result.withLock { $0 })
        // The accessor falls back to `.active` when the main thread does not answer within its timeout, so
        // either the real state or the fallback is acceptable here.
        XCTAssertTrue(state == application.applicationState || state == .active, "Unexpected state \(state.rawValue)")
    }
}
#endif
