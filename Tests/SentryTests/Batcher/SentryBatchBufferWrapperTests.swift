@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class SentryBatchBufferWrapperTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testInit_whenValidCapacity_shouldSucceed() throws {
        // -- Act --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        
        // -- Assert --
        XCTAssertEqual(sut.dataCapacity, 1_024)
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.dataSize, 0)
    }
    
    // MARK: - Add Item Tests
    
    func testAddItem_whenEmptyData_shouldReturnTrue() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        
        // -- Act --
        let result = sut.addItem(data: Data())
        
        // -- Assert --
        XCTAssertTrue(result)
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.dataSize, 0)
    }
    
    func testAddItem_whenSingleItem_shouldAddItem() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        let testData = Data("test item".utf8)
        
        // -- Act --
        let result = sut.addItem(data: testData)
        
        // -- Assert --
        XCTAssertTrue(result)
        XCTAssertEqual(sut.itemCount, 1)
        XCTAssertEqual(sut.dataSize, testData.count)
        
        let items = sut.getItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0], testData)
    }
    
    func testAddItem_whenMultipleItems_shouldAddAllItems() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        let data1 = Data("item 1".utf8)
        let data2 = Data("item 2".utf8)
        let data3 = Data("item 3".utf8)
        
        // -- Act --
        XCTAssertTrue(sut.addItem(data: data1))
        XCTAssertTrue(sut.addItem(data: data2))
        XCTAssertTrue(sut.addItem(data: data3))
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 3)
        XCTAssertEqual(sut.dataSize, data1.count + data2.count + data3.count)
        
        let items = sut.getItems()
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0], data1)
        XCTAssertEqual(items[1], data2)
        XCTAssertEqual(items[2], data3)
    }
    
    // MARK: - Capacity Limit Tests
    
    func testAddItem_whenDataCapacityExceeded_shouldReturnFalse() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 10, maxItems: 10)
        let largeData = Data(count: 11)
        
        // -- Act --
        let result = sut.addItem(data: largeData)
        
        // -- Assert --
        XCTAssertFalse(result)
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.dataSize, 0)
    }
    
    func testAddItem_whenDataCapacityExactlyFilled_shouldSucceed() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 10, maxItems: 10)
        let exactData = Data(count: 10)
        
        // -- Act --
        let result = sut.addItem(data: exactData)
        
        // -- Assert --
        XCTAssertTrue(result)
        XCTAssertEqual(sut.itemCount, 1)
        XCTAssertEqual(sut.dataSize, 10)
    }
    
    func testAddItem_whenItemCountExceeded_shouldReturnFalse() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 3)
        let data = Data("test".utf8)
        
        // -- Act --
        XCTAssertTrue(sut.addItem(data: data))
        XCTAssertTrue(sut.addItem(data: data))
        XCTAssertTrue(sut.addItem(data: data))
        let result = sut.addItem(data: data)
        
        // -- Assert --
        XCTAssertFalse(result)
        XCTAssertEqual(sut.itemCount, 3)
    }
    
    // MARK: - Get Items Tests
    
    func testGetItems_whenNoItems_shouldReturnEmptyArray() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        
        // -- Act --
        let items = sut.getItems()
        
        // -- Assert --
        XCTAssertEqual(items.count, 0)
    }
    
    func testGetItems_whenSingleItem_shouldReturnSingleItem() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        let testData = Data("test".utf8)
        sut.addItem(data: testData)
        
        // -- Act --
        let items = sut.getItems()
        
        // -- Assert --
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0], testData)
    }
    
    func testGetItems_whenMultipleItems_shouldReturnAllItems() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        let data1 = Data("item 1".utf8)
        let data2 = Data("item 2".utf8)
        let data3 = Data("item 3".utf8)
        sut.addItem(data: data1)
        sut.addItem(data: data2)
        sut.addItem(data: data3)
        
        // -- Act --
        let items = sut.getItems()
        
        // -- Assert --
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0], data1)
        XCTAssertEqual(items[1], data2)
        XCTAssertEqual(items[2], data3)
    }
    
    // MARK: - Clear Tests
    
    func testClear_whenNoItems_shouldDoNothing() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        
        // Assert pre-condition
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.dataSize, 0)
        
        // -- Act --
        sut.clear()
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.dataSize, 0)
    }
    
    func testClear_whenMultipleItems_shouldClearBuffer() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        sut.addItem(data: Data("item 1".utf8))
        sut.addItem(data: Data("item 2".utf8))
        sut.addItem(data: Data("item 3".utf8))
        
        // Assert pre-condition
        XCTAssertEqual(sut.itemCount, 3)
        XCTAssertGreaterThan(sut.dataSize, 0)
        
        // -- Act --
        sut.clear()
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.dataSize, 0)
        XCTAssertEqual(sut.getItems().count, 0)
    }
    
    func testClear_afterClear_shouldAllowNewItems() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        sut.addItem(data: Data("item 1".utf8))
        sut.addItem(data: Data("item 2".utf8))
        
        // -- Act --
        sut.clear()
        let result = sut.addItem(data: Data("item 3".utf8))
        
        // -- Assert --
        XCTAssertTrue(result)
        XCTAssertEqual(sut.itemCount, 1)
        let items = sut.getItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(String(data: items[0], encoding: .utf8), "item 3")
    }
    
    // MARK: - Property Tests
    
    func testDataSize_whenNoItems_shouldReturnZero() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        
        // -- Act --
        let size = sut.dataSize
        
        // -- Assert --
        XCTAssertEqual(size, 0)
    }
    
    func testDataSize_whenSingleItem_shouldReturnItemSize() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        let testData = Data("test".utf8)
        
        // -- Act --
        sut.addItem(data: testData)
        
        // -- Assert --
        XCTAssertEqual(sut.dataSize, testData.count)
    }
    
    func testDataSize_whenMultipleItems_shouldReturnSumOfSizes() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        let data1 = Data("item 1".utf8)
        let data2 = Data("item 2".utf8)
        let data3 = Data("item 3".utf8)
        
        // -- Act --
        sut.addItem(data: data1)
        sut.addItem(data: data2)
        sut.addItem(data: data3)
        
        // -- Assert --
        XCTAssertEqual(sut.dataSize, data1.count + data2.count + data3.count)
    }
    
    func testDataSize_afterClear_shouldReturnZero() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        sut.addItem(data: Data("test".utf8))
        sut.addItem(data: Data("test2".utf8))
        
        // Assert pre-condition
        XCTAssertGreaterThan(sut.dataSize, 0)
        
        // -- Act --
        sut.clear()
        
        // -- Assert --
        XCTAssertEqual(sut.dataSize, 0)
    }
    
    func testDataSize_shouldUpdateAfterEachAdd() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        let data1 = Data("item 1".utf8)
        let data2 = Data("item 2".utf8)
        
        // -- Act & Assert --
        XCTAssertEqual(sut.dataSize, 0)
        
        sut.addItem(data: data1)
        XCTAssertEqual(sut.dataSize, data1.count)
        
        sut.addItem(data: data2)
        XCTAssertEqual(sut.dataSize, data1.count + data2.count)
    }
    
    func testDataCapacity_shouldReturnInitialCapacity() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 2_048, maxItems: 20)
        
        // -- Act --
        let capacity = sut.dataCapacity
        
        // -- Assert --
        XCTAssertEqual(capacity, 2_048)
    }
    
    func testItemCount_whenNoItems_shouldReturnZero() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        
        // -- Act --
        let count = sut.itemCount
        
        // -- Assert --
        XCTAssertEqual(count, 0)
    }
    
    func testItemCount_whenSingleItem_shouldReturnOne() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        
        // -- Act --
        sut.addItem(data: Data("test".utf8))
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 1)
    }
    
    func testItemCount_whenMultipleItems_shouldReturnCorrectCount() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        
        // -- Act --
        sut.addItem(data: Data("item 1".utf8))
        sut.addItem(data: Data("item 2".utf8))
        sut.addItem(data: Data("item 3".utf8))
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 3)
    }
    
    func testItemCount_afterClear_shouldReturnZero() throws {
        // -- Arrange --
        let sut = try SentryBatchBufferWrapper(dataCapacity: 1_024, maxItems: 10)
        sut.addItem(data: Data("test".utf8))
        sut.addItem(data: Data("test2".utf8))
        
        // Assert pre-condition
        XCTAssertEqual(sut.itemCount, 2)
        
        // -- Act --
        sut.clear()
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 0)
    }
}
