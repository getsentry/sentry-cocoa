@_spi(Private) @testable import Sentry
import XCTest

class SentryReplayTypeTests: XCTestCase {
    func testRawValue_sessionMode_shouldBeCorrect() {
        let replayType = SentryReplayType.session.rawValue
        XCTAssertEqual(replayType, 0)
    }

    func testRawValue_bufferMode_shouldBeCorrect() {
        let replayType = SentryReplayType.buffer.rawValue
        XCTAssertEqual(replayType, 1)
    }

    func testDescription_sessionMode_shouldBeCorrect() {
        let replayType = SentryReplayType.session.description
        XCTAssertEqual(replayType, "session")
    }

    func testDescription_bufferMode_shouldBeCorrect() {
        let replayType = SentryReplayType.buffer.description
        XCTAssertEqual(replayType, "buffer")
    }

    func testToString_sessionMode_shouldBeCorrect() {
        let replayType = SentryReplayType.session
        XCTAssertEqual(replayType.toString(), "session")
    }

    func testToString_bufferMode_shouldBeCorrect() {
        let replayType = SentryReplayType.buffer
        XCTAssertEqual(replayType.toString(), "buffer")
    }
}
