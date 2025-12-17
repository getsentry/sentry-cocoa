@_spi(Private) @testable import Sentry
@_spi(Private) import SentryTestUtils
import XCTest

final class CrashSafeBatchBufferTests: XCTestCase {
    // MARK: - Initialization Tests
    
    func testInit_whenValidCapacity_shouldSucceed() throws {
        // -- Act --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.dataSize, 0)
    }
    
    func testInit_whenZeroCapacity_shouldSucceed() throws {
        // -- Act --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 0, itemsCapacity: 0)
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.dataSize, 0)
    }
    
    // MARK: - Item Count Tests
    
    func testItemCount_withNoElements_shouldReturnZero() throws {
        // -- Act --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 0)
    }
    
    func testItemCount_withSingleElement_shouldReturnOne() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        let data = Data("test".utf8)
        
        // -- Act --
        let success = sut.addItem(data)
        
        // -- Assert --
        XCTAssertTrue(success)
        XCTAssertEqual(sut.itemCount, 1)
    }
    
    func testItemCount_withMultipleElements_shouldReturnCorrectCount() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        
        // -- Act --
        XCTAssertTrue(sut.addItem(Data("item1".utf8)))
        XCTAssertTrue(sut.addItem(Data("item2".utf8)))
        XCTAssertTrue(sut.addItem(Data("item3".utf8)))
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 3)
    }
    
    // MARK: - Add Item Tests
    
    func testAddItem_withSingleElement_shouldAddElement() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        let data = Data("test".utf8)
        
        // -- Act --
        let success = sut.addItem(data)
        
        // -- Assert --
        XCTAssertTrue(success)
        XCTAssertEqual(sut.itemCount, 1)
        let items = sut.getAllItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0], data)
    }
    
    func testAddItem_withMultipleElements_shouldAddAllElements() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        let data1 = Data("item1".utf8)
        let data2 = Data("item2".utf8)
        let data3 = Data("item3".utf8)
        
        // -- Act --
        XCTAssertTrue(sut.addItem(data1))
        XCTAssertTrue(sut.addItem(data2))
        XCTAssertTrue(sut.addItem(data3))
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 3)
        let items = sut.getAllItems()
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0], data1)
        XCTAssertEqual(items[1], data2)
        XCTAssertEqual(items[2], data3)
    }
    
    func testAddItem_withMultipleElements_shouldMaintainOrder() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        
        // -- Act --
        XCTAssertTrue(sut.addItem(Data("first".utf8)))
        XCTAssertTrue(sut.addItem(Data("second".utf8)))
        XCTAssertTrue(sut.addItem(Data("third".utf8)))
        
        // -- Assert --
        let items = sut.getAllItems()
        XCTAssertEqual(String(data: items[0], encoding: .utf8), "first")
        XCTAssertEqual(String(data: items[1], encoding: .utf8), "second")
        XCTAssertEqual(String(data: items[2], encoding: .utf8), "third")
    }
    
    func testAddItem_withEmptyData_shouldReturnTrue() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        
        // -- Act --
        let success = sut.addItem(Data())
        
        // -- Assert --
        XCTAssertTrue(success)
        XCTAssertEqual(sut.itemCount, 0) // Empty data doesn't add an item
    }
    
    func testAddItem_whenBufferFull_shouldReturnFalse() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 10, itemsCapacity: 2)
        let largeData = Data("this is too large".utf8) // 17 bytes, exceeds capacity
        
        // -- Act --
        let success = sut.addItem(largeData)
        
        // -- Assert --
        XCTAssertFalse(success)
    }
    
    func testAddItem_whenItemsCapacityReached_shouldReturnFalse() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 2)
        
        // -- Act --
        XCTAssertTrue(sut.addItem(Data("item1".utf8)))
        XCTAssertTrue(sut.addItem(Data("item2".utf8)))
        let success = sut.addItem(Data("item3".utf8)) // Should fail
        
        // -- Assert --
        XCTAssertFalse(success)
        XCTAssertEqual(sut.itemCount, 2)
    }
    
    // MARK: - Data Size Tests
    
    func testDataSize_withNoElements_shouldReturnZero() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        
        // -- Act --
        let size = sut.dataSize
        
        // -- Assert --
        XCTAssertEqual(size, 0)
    }
    
    func testDataSize_withSingleElement_shouldReturnElementSize() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        let data = Data("test".utf8)
        
        // -- Act --
        XCTAssertTrue(sut.addItem(data))
        
        // -- Assert --
        XCTAssertEqual(sut.dataSize, data.count)
    }
    
    func testDataSize_withMultipleElements_shouldReturnSumOfSizes() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        let data1 = Data("item1".utf8)
        let data2 = Data("item2".utf8)
        let data3 = Data("item3".utf8)
        
        // -- Act --
        XCTAssertTrue(sut.addItem(data1))
        XCTAssertTrue(sut.addItem(data2))
        XCTAssertTrue(sut.addItem(data3))
        
        // -- Assert --
        XCTAssertEqual(sut.dataSize, data1.count + data2.count + data3.count)
    }
    
    func testDataSize_afterClear_shouldReturnZero() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        XCTAssertTrue(sut.addItem(Data("test1".utf8)))
        XCTAssertTrue(sut.addItem(Data("test2".utf8)))
        
        // Assert pre-condition
        XCTAssertGreaterThan(sut.dataSize, 0)
        
        // -- Act --
        sut.clear()
        
        // -- Assert --
        XCTAssertEqual(sut.dataSize, 0)
    }
    
    func testDataSize_shouldUpdateAfterEachAdd() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        let data1 = Data("first".utf8)
        let data2 = Data("second".utf8)
        
        // -- Act & Assert --
        XCTAssertEqual(sut.dataSize, 0)
        
        XCTAssertTrue(sut.addItem(data1))
        XCTAssertEqual(sut.dataSize, data1.count)
        
        XCTAssertTrue(sut.addItem(data2))
        XCTAssertEqual(sut.dataSize, data1.count + data2.count)
    }
    
    // MARK: - Clear Tests
    
    func testClear_withNoElements_shouldDoNothing() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        
        // Assert pre-condition
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.dataSize, 0)
        
        // -- Act --
        sut.clear()
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.dataSize, 0)
    }
    
    func testClear_withSingleElement_shouldClearStorage() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        XCTAssertTrue(sut.addItem(Data("test".utf8)))
        
        // Assert pre-condition
        XCTAssertEqual(sut.itemCount, 1)
        XCTAssertGreaterThan(sut.dataSize, 0)
        
        // -- Act --
        sut.clear()
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.dataSize, 0)
        XCTAssertEqual(sut.getAllItems().count, 0)
    }
    
    func testClear_withMultipleElements_shouldClearStorage() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        XCTAssertTrue(sut.addItem(Data("item1".utf8)))
        XCTAssertTrue(sut.addItem(Data("item2".utf8)))
        XCTAssertTrue(sut.addItem(Data("item3".utf8)))
        
        // Assert pre-condition
        XCTAssertEqual(sut.itemCount, 3)
        XCTAssertGreaterThan(sut.dataSize, 0)
        
        // -- Act --
        sut.clear()
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.dataSize, 0)
        XCTAssertEqual(sut.getAllItems().count, 0)
    }
    
    func testClear_afterClear_shouldAllowNewAdds() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        XCTAssertTrue(sut.addItem(Data("item1".utf8)))
        XCTAssertTrue(sut.addItem(Data("item2".utf8)))
        
        // -- Act --
        sut.clear()
        XCTAssertTrue(sut.addItem(Data("item3".utf8)))
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 1)
        let items = sut.getAllItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(String(data: items[0], encoding: .utf8), "item3")
    }
    
    func testMultipleClearCalls_shouldNotCauseIssues() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        XCTAssertTrue(sut.addItem(Data("test".utf8)))
        
        // -- Act --
        sut.clear()
        sut.clear()
        sut.clear()
        
        // -- Assert --
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.dataSize, 0)
        XCTAssertEqual(sut.getAllItems().count, 0)
    }
    
    // MARK: - GetAllItems Tests
    
    func testGetAllItems_withNoElements_shouldReturnEmptyArray() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        
        // -- Act --
        let items = sut.getAllItems()
        
        // -- Assert --
        XCTAssertEqual(items.count, 0)
    }
    
    func testGetAllItems_withSingleElement_shouldReturnSingleElement() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        let data = Data("test".utf8)
        XCTAssertTrue(sut.addItem(data))
        
        // -- Act --
        let items = sut.getAllItems()
        
        // -- Assert --
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0], data)
    }
    
    func testGetAllItems_withMultipleElements_shouldReturnAllElements() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        let data1 = Data("item1".utf8)
        let data2 = Data("item2".utf8)
        let data3 = Data("item3".utf8)
        XCTAssertTrue(sut.addItem(data1))
        XCTAssertTrue(sut.addItem(data2))
        XCTAssertTrue(sut.addItem(data3))
        
        // -- Act --
        let items = sut.getAllItems()
        
        // -- Assert --
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0], data1)
        XCTAssertEqual(items[1], data2)
        XCTAssertEqual(items[2], data3)
    }
    
    func testGetAllItems_shouldMaintainElementOrder() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        XCTAssertTrue(sut.addItem(Data("first".utf8)))
        XCTAssertTrue(sut.addItem(Data("second".utf8)))
        XCTAssertTrue(sut.addItem(Data("third".utf8)))
        
        // -- Act --
        let items = sut.getAllItems()
        
        // -- Assert --
        XCTAssertEqual(String(data: items[0], encoding: .utf8), "first")
        XCTAssertEqual(String(data: items[1], encoding: .utf8), "second")
        XCTAssertEqual(String(data: items[2], encoding: .utf8), "third")
    }
    
    // MARK: - Integration Tests
    
    func testAddClearAdd_shouldWorkCorrectly() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        
        // -- Act & Assert --
        XCTAssertTrue(sut.addItem(Data("item1".utf8)))
        XCTAssertEqual(sut.itemCount, 1)
        XCTAssertGreaterThan(sut.dataSize, 0)
        
        sut.clear()
        XCTAssertEqual(sut.itemCount, 0)
        XCTAssertEqual(sut.dataSize, 0)
        
        XCTAssertTrue(sut.addItem(Data("item2".utf8)))
        XCTAssertTrue(sut.addItem(Data("item3".utf8)))
        XCTAssertEqual(sut.itemCount, 2)
        
        let items = sut.getAllItems()
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(String(data: items[0], encoding: .utf8), "item2")
        XCTAssertEqual(String(data: items[1], encoding: .utf8), "item3")
    }
    
    // MARK: - Binary Data Tests
    
    func testAddItem_withBinaryData_shouldPreserveData() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 1_024, itemsCapacity: 10)
        let binaryData = Data([0x00, 0x01, 0x02, 0xFF, 0xFE, 0xFD])
        
        // -- Act --
        XCTAssertTrue(sut.addItem(binaryData))
        
        // -- Assert --
        let items = sut.getAllItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0], binaryData)
    }
    
    func testAddItem_withLargeData_shouldWork() throws {
        // -- Arrange --
        let sut = try CrashSafeBatchBuffer(dataCapacity: 10_000, itemsCapacity: 100)
        let largeData = Data(repeating: 0x42, count: 5_000)
        
        // -- Act --
        let success = sut.addItem(largeData)
        
        // -- Assert --
        XCTAssertTrue(success)
        XCTAssertEqual(sut.itemCount, 1)
        XCTAssertEqual(sut.dataSize, 5_000)
        let items = sut.getAllItems()
        XCTAssertEqual(items[0].count, 5_000)
    }
}
