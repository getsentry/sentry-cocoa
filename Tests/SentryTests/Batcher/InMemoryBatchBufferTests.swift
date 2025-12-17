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

    func testCount_withNoElements_shouldReturnZero() throws {
        // -- Act --
        let sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 0)
    }

    func testCount_withSingleElement_shouldReturnOne() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)

        // -- Act --
        try sut.append(TestElement(id: 1))

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 1)
    }

    func testCount_withMultipleElements_shouldReturnCorrectCount() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)

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
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)

        // -- Act --
        try sut.append(TestElement(id: 1))

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 1)
        let decoded = try decodePayload(data: sut.batchedData)
        XCTAssertEqual(decoded.items, [TestElement(id: 1)])
    }

    func testAppend_withMultipleElements_shouldAddAllElements() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)

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
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)

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
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)
        let initialSize = sut.itemsDataSize
        XCTAssertEqual(initialSize, 0)

        // -- Act --
        let element1 = TestElement(id: 1)
        let encoded1 = try JSONEncoder().encode(element1)
        try sut.append(element1)

        // -- Assert --
        XCTAssertEqual(sut.itemsDataSize, encoded1.count)

        // -- Act --
        let element2 = TestElement(id: 2)
        let encoded2 = try JSONEncoder().encode(element2)
        try sut.append(element2)

        // -- Assert --
        XCTAssertEqual(sut.itemsDataSize, encoded1.count + encoded2.count)
    }

    // MARK: - Flush Method Tests

    func testFlush_withNoElements_shouldDoNothing() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)

        // Assert pre-condition
        XCTAssertEqual(sut.itemsCount, 0)
        XCTAssertEqual(sut.itemsDataSize, 0)

        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 0)
        XCTAssertEqual(sut.itemsDataSize, 0)
    }

    func testFlush_withSingleElement_shouldClearStorage() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)
        try sut.append(TestElement(id: 1))

        // Assert pre-condition
        XCTAssertEqual(sut.itemsCount, 1)
        XCTAssertGreaterThan(sut.itemsDataSize, 0)

        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 0)
        XCTAssertEqual(sut.itemsDataSize, 0)
        let decoded = try decodePayload(data: sut.batchedData)
        XCTAssertEqual(decoded.items, [])
    }

    func testFlush_withMultipleElements_shouldClearStorage() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)
        try sut.append(TestElement(id: 1))
        try sut.append(TestElement(id: 2))
        try sut.append(TestElement(id: 3))

        // Assert pre-condition
        XCTAssertEqual(sut.itemsCount, 3)
        XCTAssertGreaterThan(sut.itemsDataSize, 0)

        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 0)
        XCTAssertEqual(sut.itemsDataSize, 0)
        let decoded = try decodePayload(data: sut.batchedData)
        XCTAssertEqual(decoded.items, [])
    }

    func testFlush_afterFlush_shouldAllowNewAppends() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)
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

    func testData_withNoElements_shouldReturnEmptyArray() throws {
        // -- Arrange --
        let sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)

        // -- Act --
        let data = sut.batchedData

        // -- Assert --
        let decoded = try decodePayload(data: data)
        XCTAssertEqual(decoded.items, [])
    }

    func testData_withSingleElement_shouldReturnSingleElement() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)
        try sut.append(TestElement(id: 1))

        // -- Act --
        let data = sut.batchedData

        // -- Assert --
        let decoded = try decodePayload(data: data)
        XCTAssertEqual(decoded.items, [TestElement(id: 1)])
    }

    func testData_withMultipleElements_shouldReturnAllElements() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)
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

    func testData_shouldReturnValidJSONFormat() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)
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

    func testData_shouldMaintainElementOrder() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)
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

    func testSize_withNoElements_shouldReturnZero() throws {
        // -- Arrange --
        let sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)

        // -- Act --
        let size = sut.itemsDataSize

        // -- Assert --
        XCTAssertEqual(size, 0)
    }

    func testSize_withSingleElement_shouldReturnEncodedElementSize() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)
        let element = TestElement(id: 1)
        let expectedSize = try JSONEncoder().encode(element).count

        // -- Act --
        try sut.append(element)

        // -- Assert --
        XCTAssertEqual(sut.itemsDataSize, expectedSize)
    }

    func testSize_withMultipleElements_shouldReturnSumOfEncodedSizes() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)
        let element1 = TestElement(id: 1)
        let element2 = TestElement(id: 2)
        let element3 = TestElement(id: 3)
        let encoder = JSONEncoder()
        let expectedSize1 = try encoder.encode(element1).count
        let expectedSize2 = try encoder.encode(element2).count
        let expectedSize3 = try encoder.encode(element3).count
        let expectedTotalSize = expectedSize1 + expectedSize2 + expectedSize3

        // -- Act --
        try sut.append(element1)
        try sut.append(element2)
        try sut.append(element3)

        // -- Assert --
        XCTAssertEqual(sut.itemsDataSize, expectedTotalSize)
    }

    func testSize_afterFlush_shouldReturnZero() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)
        try sut.append(TestElement(id: 1))
        try sut.append(TestElement(id: 2))

        // Assert pre-condition
        XCTAssertGreaterThan(sut.itemsDataSize, 0)

        // -- Act --
        sut.clear()

        // -- Assert --
        XCTAssertEqual(sut.itemsDataSize, 0)
    }

    func testSize_shouldUpdateAfterEachAppend() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)
        let element1 = TestElement(id: 1)
        let element2 = TestElement(id: 2)
        let encoder = JSONEncoder()
        let size1 = try encoder.encode(element1).count
        let size2 = try encoder.encode(element2).count

        // -- Act & Assert --
        XCTAssertEqual(sut.itemsDataSize, 0)

        try sut.append(element1)
        XCTAssertEqual(sut.itemsDataSize, size1)

        try sut.append(element2)
        XCTAssertEqual(sut.itemsDataSize, size1 + size2)
    }

    // MARK: - Integration Tests

    func testAppendFlushAppend_shouldWorkCorrectly() throws {
        // -- Arrange --
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)

        // -- Act & Assert --
        try sut.append(TestElement(id: 1))
        XCTAssertEqual(sut.itemsCount, 1)
        XCTAssertGreaterThan(sut.itemsDataSize, 0)

        sut.clear()
        XCTAssertEqual(sut.itemsCount, 0)
        XCTAssertEqual(sut.itemsDataSize, 0)

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
        var sut = InMemoryBatchBuffer<TestElement>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)
        try sut.append(TestElement(id: 1))

        // -- Act --
        sut.clear()
        sut.clear()
        sut.clear()

        // -- Assert --
        XCTAssertEqual(sut.itemsCount, 0)
        XCTAssertEqual(sut.itemsDataSize, 0)
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
        var sut = InMemoryBatchBuffer<TestElementWithDate>(dataCapacity: 1_024 * 1_024, maxItems: 1_000)
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
