import SentryTestUtils
import XCTest

final class TestCurrentDateProviderTests: XCTestCase {

    func testAdvanceBySeconds_FromMultipleThreads() throws {
        // Arrange
        let sut = TestCurrentDateProvider()

        let addedTimeInterval: TimeInterval = 1_000
        let expectedDate = sut.date().addingTimeInterval(1_000)
        let expectedSystemTime = addedTimeInterval.toNanoSeconds()

        let dispatchQueue = DispatchQueue(label: "TestCurrentDateProviderTests", attributes: [.concurrent, .initiallyInactive])

        let expectation = self.expectation(description: "testAdvanceByFromMultipleThreads")
        expectation.expectedFulfillmentCount = 1_000

        // Act
        for _ in 0..<1_000 {
           dispatchQueue.async {
               sut.advance(by: 1)
               expectation.fulfill()
           }
        }

        dispatchQueue.activate()
        wait(for: [expectation], timeout: 5.0)

        // Assert
        XCTAssertEqual(sut.date(), expectedDate)
        XCTAssertEqual(sut.systemTime(), expectedSystemTime)
    }

    func testAdvanceByNanoSeconds_FromMultipleThreads() throws {
        // Arrange
        let sut = TestCurrentDateProvider()

        let addedTimeInterval: TimeInterval = 1_000
        let expectedDate = sut.date().addingTimeInterval(1_000)
        let expectedSystemTime = addedTimeInterval.toNanoSeconds()

        let dispatchQueue = DispatchQueue(label: "TestCurrentDateProviderTests", attributes: [.concurrent, .initiallyInactive])

        let expectation = self.expectation(description: "testAdvanceByNanoSecondsFromMultipleThreads")
        expectation.expectedFulfillmentCount = 1_000

        // Act
        for _ in 0..<1_000 {
           dispatchQueue.async {
               sut.advanceBy(nanoseconds: 1.toNanoSeconds())
               expectation.fulfill()
           }
        }

        dispatchQueue.activate()
        wait(for: [expectation], timeout: 5.0)

        // Assert
        XCTAssertEqual(sut.date(), expectedDate)
        XCTAssertEqual(sut.systemTime(), expectedSystemTime)
    }

    func testAdvanceByInterval_FromMultipleThreads() throws {
        // Arrange
        let sut = TestCurrentDateProvider()

        let addedTimeInterval: TimeInterval = 1_000
        let expectedDate = sut.date().addingTimeInterval(1_000)
        let expectedSystemTime = addedTimeInterval.toNanoSeconds()

        let dispatchQueue = DispatchQueue(label: "TestCurrentDateProviderTests", attributes: [.concurrent, .initiallyInactive])

        let expectation = self.expectation(description: "testAdvanceByNanoSecondsFromMultipleThreads")
        expectation.expectedFulfillmentCount = 1_000

        // Act
        for _ in 0..<1_000 {
           dispatchQueue.async {
               sut.advanceBy(interval: TimeInterval(1.0))
               expectation.fulfill()
           }
        }

        dispatchQueue.activate()
        wait(for: [expectation], timeout: 5.0)

        // Assert
        XCTAssertEqual(sut.date(), expectedDate)
        XCTAssertEqual(sut.systemTime(), expectedSystemTime)
    }

    // This test only accesses all APIs from multiple threads so the ThreadSanitizer can catch any race conditions.
    func testAccessAllApis_FromMultipleThreads() throws {
        // Arrange
        let sut = TestCurrentDateProvider()
        sut.driftTimeForEveryRead = false

        let dispatchQueue = DispatchQueue(label: "TestCurrentDateProviderTests", attributes: [.concurrent, .initiallyInactive])

        let expectation = self.expectation(description: "testAdvanceByNanoSecondsFromMultipleThreads")
        expectation.expectedFulfillmentCount = 1_000

        // Act
        for i in 0..<1_000 {
            dispatchQueue.async {

                XCTAssertNotNil(sut.date())
                sut.setDate(date: Date())
                sut.reset()
                XCTAssertGreaterThanOrEqual(sut.systemTime(), 0)
                XCTAssertGreaterThanOrEqual(sut.systemUptime(), 0.0)
                sut.setSystemUptime(TimeInterval(i))

                sut.advance(by: 1.0)
                sut.advanceBy(interval: TimeInterval(1.0))
                sut.advanceBy(nanoseconds: 1.toNanoSeconds())

                sut.timezoneOffsetValue = i
                XCTAssertGreaterThanOrEqual(sut.timezoneOffset(), 0)
                XCTAssertGreaterThanOrEqual(sut.timezoneOffsetValue, 0)

                expectation.fulfill()
            }
        }

        dispatchQueue.activate()
        wait(for: [expectation], timeout: 5.0)
    }

}
