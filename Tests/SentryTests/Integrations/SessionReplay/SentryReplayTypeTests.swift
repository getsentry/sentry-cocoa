@testable import Sentry
import XCTest

class SentryReplayTypeTests: XCTestCase {
    func testRawValue_bufferMode_shouldBeCorrect() {
        let buffer = SentryReplayType.buffer.rawValue
        XCTAssertEqual(buffer, 0)
    }

    func testRawValue_sessionMode_shouldBeCorrect() {
        let replay = SentryReplayType.session.rawValue
        XCTAssertEqual(replay, 1)
    }

    func testDescription_bufferMode_shouldBeCorrect() {
        let replay = SentryReplayType.session.description
        XCTAssertEqual(replay, "buffer")
    }

    func testDescription_sessionMode_shouldBeCorrect() {
        let replay = SentryReplayType.session.description
        XCTAssertEqual(replay, "session")
    }

    func testToString_bufferMode_shouldBeCorrect() {
        let replay = SentryReplayType.buffer
        XCTAssertEqual(replay.toString(), "buffer")
    }

    func testToString_sessionMode_shouldBeCorrect() {
        let replay = SentryReplayType.session
        XCTAssertEqual(replay.toString(), "session")
    }
}
