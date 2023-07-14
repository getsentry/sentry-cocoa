import XCTest

final class SentryThreadWrapperTests: XCTestCase {
    func testOnMainThreadFromMainThread() {
        let e = expectation(description: "Asserted that execution happened on main thread")
        SentryThreadWrapper.onMainThread {
            XCTAssertTrue(Thread.isMainThread)
            e.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testOnMainThreadFromNonMainContext() {
        let e = expectation(description: "Asserted that execution happened on main thread")
        let q = DispatchQueue(label: "a nonmain queue", qos: .background)
        q.async {
            XCTAssertFalse(Thread.isMainThread)
            SentryThreadWrapper.onMainThread {
                XCTAssertTrue(Thread.isMainThread)
                e.fulfill()
            }
        }
        waitForExpectations(timeout: 1)
    }
}
