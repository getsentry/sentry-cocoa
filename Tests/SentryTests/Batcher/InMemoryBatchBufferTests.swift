@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class InMemoryBatchBufferTests: XCTestCase {
    private struct TestElement: Codable, Equatable {
        let id: Int
    }

    private struct TestPayload: Decodable {
        let items: [TestElement]
    }

    // MARK: - Count Property Tests

    func testCount_withNoElements_shouldReturnZero() {
        // -- Act --
        let sut = InMemoryBatchBuffer<TestElement>()

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 0)
    }

    func testCount_withSingleElement_shouldReturnOne() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()

        // -- Act --
        try sut.append(TestElement(id: 1))

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 1)
    }

    func testCount_withMultipleElements_shouldReturnCorrectCount() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()

        // -- Act --
        try sut.append(TestElement(id: 1))
        try sut.append(TestElement(id: 2))
        try sut.append(TestElement(id: 3))

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 3)
    }

    // MARK: - Append Method Tests

    func testAppend_withSingleElement_shouldAddElement() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()

        // -- Act --
        try sut.append(TestElement(id: 1))

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 1)
        let decoded = try decodePayload(data: sut.batchedData)
        XCTAssertEqual(decoded.items, [TestElement(id: 1)])
    }

    func testAppend_withMultipleElements_shouldAddAllElements() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()

        // -- Act --
        try sut.append(TestElement(id: 1))
        try sut.append(TestElement(id: 2))
        try sut.append(TestElement(id: 3))

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 3)
        let decoded = try decodePayload(data: sut.batchedData)
        XCTAssertEqual(decoded.items, [
            TestElement(id: 1),
            TestElement(id: 2),
            TestElement(id: 3)
        ])
    }

    func testAppend_withMultipleElements_shouldMaintainOrder() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()

        // -- Act --
        try sut.append(TestElement(id: 1))
        try sut.append(TestElement(id: 2))
        try sut.append(TestElement(id: 3))

        // -- Assert --
        let decoded = try decodePayload(data: sut.batchedData)
        XCTAssertEqual(decoded.items[0].id, 1)
        XCTAssertEqual(decoded.items[1].id, 2)
        XCTAssertEqual(decoded.items[2].id, 3)
    }

    func testAppend_shouldIncreaseSize() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()
        let initialSize = sut.batchedData.count
        // Initial size is the empty payload: {"items":[]} = 12 bytes
        XCTAssertEqual(initialSize, 12)

        // -- Act --
        let element1 = TestElement(id: 1)
        let encoded1 = try JSONEncoder().encode(element1)
        try sut.append(element1)

        // -- Assert --
        // batchedDataSize includes the complete JSON structure: {"items":[item1]}
        // Prefix (10 bytes) + item1 + suffix (2 bytes) = 10 + encoded1.count + 2
        let expectedSize1 = 10 + encoded1.count + 2
        XCTAssertEqual(sut.batchedData.count, expectedSize1)

        // -- Act --
        let element2 = TestElement(id: 2)
        let encoded2 = try JSONEncoder().encode(element2)
        try sut.append(element2)

        // -- Assert --
        // batchedDataSize includes: {"items":[item1,item2]}
        // Prefix (10) + item1 + comma (1) + item2 + suffix (2) = 10 + encoded1.count + 1 + encoded2.count + 2
        let expectedSize2 = 10 + encoded1.count + 1 + encoded2.count + 2
        XCTAssertEqual(sut.batchedData.count, expectedSize2)
    }

    // MARK: - Flush Method Tests

    func testClear_withNoElements_shouldDoNothing() {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()

        // Assert pre-condition
        XCTAssertEqual(sut.itemsCount, 0)
        XCTAssertEqual(sut.batchedData.count, 12) // Empty payload size

        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 0)
        XCTAssertEqual(sut.batchedData.count, 12) // Empty payload size after clear
    }

    func testClear_withSingleElement_shouldClearStorage() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()
        try sut.append(TestElement(id: 1))

        // Assert pre-condition
        XCTAssertEqual(sut.itemsCount, 1)
        XCTAssertGreaterThan(sut.batchedData.count, 0)

        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 0)
        XCTAssertEqual(sut.batchedData.count, 12)
        let decoded = try decodePayload(data: sut.batchedData)
        XCTAssertEqual(decoded.items, [])
    }

    func testClear_withMultipleElements_shouldClearStorage() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()
        try sut.append(TestElement(id: 1))
        try sut.append(TestElement(id: 2))
        try sut.append(TestElement(id: 3))

        // Assert pre-condition
        XCTAssertEqual(sut.itemsCount, 3)
        XCTAssertGreaterThan(sut.batchedData.count, 0)

        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 0)
        XCTAssertEqual(sut.batchedData.count, 12)
        let decoded = try decodePayload(data: sut.batchedData)
        XCTAssertEqual(decoded.items, [])
    }

    func testClear_afterFlush_shouldAllowNewAppends() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()
        try sut.append(TestElement(id: 1))
        try sut.append(TestElement(id: 2))

        // -- Act --
        sut.clear()
        try sut.append(TestElement(id: 3))

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 1)
        let decoded = try decodePayload(data: sut.batchedData)
        XCTAssertEqual(decoded.items, [TestElement(id: 3)])
    }

    // MARK: - Data Property Tests

    func testBatchedData_withNoElements_shouldReturnEmptyArray() throws {
        // -- Arrange --
        let sut = InMemoryBatchBuffer<TestElement>()

        // -- Act --
        let data = sut.batchedData

        // -- Assert --
        let decoded = try decodePayload(data: data)
        XCTAssertEqual(decoded.items, [])
    }

    func testBatchedData_withSingleElement_shouldReturnSingleElement() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()
        try sut.append(TestElement(id: 1))

        // -- Act --
        let data = sut.batchedData

        // -- Assert --
        let decoded = try decodePayload(data: data)
        XCTAssertEqual(decoded.items, [TestElement(id: 1)])
    }

    func testBatchedData_withMultipleElements_shouldReturnAllElements() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()
        try sut.append(TestElement(id: 1))
        try sut.append(TestElement(id: 2))
        try sut.append(TestElement(id: 3))

        // -- Act --
        let data = sut.batchedData

        // -- Assert --
        let decoded = try decodePayload(data: data)
        XCTAssertEqual(decoded.items, [
            TestElement(id: 1),
            TestElement(id: 2),
            TestElement(id: 3)
        ])
    }

    func testBatched_shouldReturnValidJSONFormat() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()
        try sut.append(TestElement(id: 1))
        try sut.append(TestElement(id: 2))

        // -- Act --
        let data = sut.batchedData

        // -- Assert --
        // Verify it's valid JSON by decoding
        let decoded = try decodePayload(data: data)
        XCTAssertEqual(decoded.items.count, 2)
        
        // Verify JSON structure by checking string representation
        let jsonString = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(jsonString.hasPrefix("{\"items\":["))
        XCTAssertTrue(jsonString.hasSuffix("]}"))
    }

    func testBatched_shouldMaintainElementOrder() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()
        try sut.append(TestElement(id: 10))
        try sut.append(TestElement(id: 20))
        try sut.append(TestElement(id: 30))

        // -- Act --
        let data = sut.batchedData

        // -- Assert --
        let decoded = try decodePayload(data: data)
        XCTAssertEqual(decoded.items[0].id, 10)
        XCTAssertEqual(decoded.items[1].id, 20)
        XCTAssertEqual(decoded.items[2].id, 30)
    }

    // MARK: - Size Property Tests

    func testBatchedDataSize_withNoElements_shouldReturnEmptyPayloadSize() {
        // -- Arrange --
        let sut = InMemoryBatchBuffer<TestElement>()

        // -- Act --
        let size = sut.batchedData.count

        // -- Assert --
        // batchedDataSize returns the size of the empty JSON payload: {"items":[]} = 12 bytes
        XCTAssertEqual(size, 12)
    }

    func testBatchedDataSize_withSingleElement_shouldReturnEncodedElementSize() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()
        let element = TestElement(id: 1)
        let encodedSize = try JSONEncoder().encode(element).count

        // -- Act --
        try sut.append(element)

        // -- Assert --
        // batchedDataSize includes the complete JSON structure: {"items":[item]}
        // Prefix (10 bytes) + encoded item + suffix (2 bytes)
        let expectedSize = 10 + encodedSize + 2
        XCTAssertEqual(sut.batchedData.count, expectedSize)
    }

    func testBatchedDataSize_withMultipleElements_shouldReturnSumOfEncodedSizes() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()
        let element1 = TestElement(id: 1)
        let element2 = TestElement(id: 2)
        let element3 = TestElement(id: 3)
        let encoder = JSONEncoder()
        let encodedSize1 = try encoder.encode(element1).count
        let encodedSize2 = try encoder.encode(element2).count
        let encodedSize3 = try encoder.encode(element3).count

        // -- Act --
        try sut.append(element1)
        try sut.append(element2)
        try sut.append(element3)

        // -- Assert --
        // batchedDataSize includes the complete JSON structure: {"items":[item1,item2,item3]}
        // Prefix (10) + item1 + comma (1) + item2 + comma (1) + item3 + suffix (2)
        let expectedTotalSize = 10 + encodedSize1 + 1 + encodedSize2 + 1 + encodedSize3 + 2
        XCTAssertEqual(sut.batchedData.count, expectedTotalSize)
    }

    func testBatchedDataSize_afterFlush_shouldReturnDefault() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()
        try sut.append(TestElement(id: 1))
        try sut.append(TestElement(id: 2))

        // Assert pre-condition
        XCTAssertGreaterThan(sut.batchedData.count, 12)

        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertEqual(sut.batchedData.count, 12)
    }

    func testBatchedDataSize_shouldUpdateAfterEachAppend() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()
        let element1 = TestElement(id: 1)
        let element2 = TestElement(id: 2)
        let encoder = JSONEncoder()
        let encodedSize1 = try encoder.encode(element1).count
        let encodedSize2 = try encoder.encode(element2).count

        // -- Act & Assert --
        // Initial size is the empty payload: {"items":[]} = 12 bytes
        XCTAssertEqual(sut.batchedData.count, 12)

        try sut.append(element1)
        // After first item: {"items":[item1]} = prefix (10) + item1 + suffix (2)
        let expectedSize1 = 10 + encodedSize1 + 2
        XCTAssertEqual(sut.batchedData.count, expectedSize1)

        try sut.append(element2)
        // After second item: {"items":[item1,item2]} = prefix (10) + item1 + comma (1) + item2 + suffix (2)
        let expectedSize2 = 10 + encodedSize1 + 1 + encodedSize2 + 2
        XCTAssertEqual(sut.batchedData.count, expectedSize2)
    }

    // MARK: - Integration Tests

    func testAppendClearAppend_shouldWorkCorrectly() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()

        // -- Act & Assert --
        try sut.append(TestElement(id: 1))
        XCTAssertEqual(sut.itemsCount, 1)
        XCTAssertGreaterThan(sut.batchedData.count, 0)

        sut.clear()
        XCTAssertEqual(sut.itemsCount, 0)
        XCTAssertEqual(sut.batchedData.count, 12) // Empty payload size

        try sut.append(TestElement(id: 2))
        try sut.append(TestElement(id: 3))
        XCTAssertEqual(sut.itemsCount, 2)

        let decoded = try decodePayload(data: sut.batchedData)
        XCTAssertEqual(decoded.items, [
            TestElement(id: 2),
            TestElement(id: 3)
        ])
    }

    func testMultipleFlushCalls_shouldNotCauseIssues() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>()
        try sut.append(TestElement(id: 1))

        // -- Act --
        sut.clear()
        sut.clear()
        sut.clear()

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 0)
        XCTAssertEqual(sut.batchedData.count, 12) // Empty payload size
        let decoded = try decodePayload(data: sut.batchedData)
        XCTAssertEqual(decoded.items, [])
    }

    // MARK: - Date Encoding Tests

    private struct TestElementWithDate: Codable {
        let id: Int
        let timestamp: Date
    }

    private struct TestPayloadWithDate: Decodable {
        let items: [TestElementWithDate]
    }

    func testAppend_withDateProperty_shouldEncodeAsSecondsSince1970() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElementWithDate>()
        let expectedTimestamp = Date(timeIntervalSince1970: 1_234_567_890.987654)
        let element = TestElementWithDate(id: 1, timestamp: expectedTimestamp)

        // -- Act --
        try sut.append(element)

        // -- Assert --
        let data = sut.batchedData
        let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = try XCTUnwrap(jsonObject?["items"] as? [[String: Any]])
        let firstItem = try XCTUnwrap(items.first)
        
        // Verify timestamp is encoded as seconds since 1970 (not seconds since reference date)
        let timestampValue = try XCTUnwrap(firstItem["timestamp"] as? TimeInterval)
        XCTAssertEqual(timestampValue, 1_234_567_890.987654, accuracy: 0.000001)
        
        // Verify we can decode it back correctly
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(TestPayloadWithDate.self, from: data)
        let decodedItem = try XCTUnwrap(decoded.items.first)
        XCTAssertEqual(
            decodedItem.timestamp.timeIntervalSince1970,
            expectedTimestamp.timeIntervalSince1970,
            accuracy: 0.000001
        )
    }

    // MARK: - Helpers

    private func decodePayload(data: Data) throws -> TestPayload {
        return try JSONDecoder().decode(TestPayload.self, from: data)
    }
}
