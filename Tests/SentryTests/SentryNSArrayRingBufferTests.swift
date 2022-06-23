import XCTest

class SentryNSArrayRingBufferTests: XCTestCase {
    func testEmptyRingBufferReturnsEmptyArray() {
        let emptyBuffer = SentryNSArrayRingBuffer<NSNumber>(capacity: 3)
        let array = emptyBuffer.array
        XCTAssertEqual(array.count, 0)
    }

    func testRingBufferWithFewerElementsAddedThanCapacityAllowsReturnsArrayWithElementsInOrder() {
        let buffer = SentryNSArrayRingBuffer<NSNumber>(capacity: 3)
        buffer.add(1)
        buffer.add(2)

        let array = buffer.array
        XCTAssertEqual(array.count, 2)
        XCTAssertEqual(array[0], 1)
        XCTAssertEqual(array[1], 2)
    }

    func testRingBufferAtCapacityReturnsArrayWithElementsInOrder() {
        let buffer = SentryNSArrayRingBuffer<NSNumber>(capacity: 3)
        buffer.add(1)
        buffer.add(2)
        buffer.add(3)

        let array = buffer.array
        XCTAssertEqual(array.count, 3)
        XCTAssertEqual(array[0], 1)
        XCTAssertEqual(array[1], 2)
        XCTAssertEqual(array[2], 3)
    }

    func testRingBufferWithMoreElementsAddedThanCapacityAllowsReturnsArrayWithElementsInOrder() {
        let buffer = SentryNSArrayRingBuffer<NSNumber>(capacity: 3)
        buffer.add(1)
        buffer.add(2)
        buffer.add(3)
        buffer.add(4)

        let array = buffer.array
        XCTAssertEqual(array.count, 3)
        XCTAssertEqual(array[0], 2)
        XCTAssertEqual(array[1], 3)
        XCTAssertEqual(array[2], 4)
    }
}
