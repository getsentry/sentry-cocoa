@_spi(Private) import SentryTestUtils
import XCTest

final class InvocationsTests: XCTestCase {

    func testInitialStateIsEmpty() throws {
        // Arrange & Act
        let sut = Invocations<String>()
        
        // Assert
        XCTAssertTrue(sut.isEmpty)
        XCTAssertEqual(sut.count, 0)
        XCTAssertTrue(sut.invocations.isEmpty)
        XCTAssertNil(sut.first)
        XCTAssertNil(sut.last)
    }
    
    func testRecordSingleInvocation() throws {
        // Arrange
        let sut = Invocations<String>()
        let testValue = "test"
        
        // Act
        sut.record(testValue)
        
        // Assert
        XCTAssertFalse(sut.isEmpty)
        XCTAssertEqual(sut.count, 1)
        XCTAssertEqual(sut.invocations.count, 1)
        XCTAssertEqual(sut.first, testValue)
        XCTAssertEqual(sut.last, testValue)
        XCTAssertEqual(sut.invocations[0], testValue)
    }
    
    func testRecordMultipleInvocations() throws {
        // Arrange
        let sut = Invocations<Int>()
        let values = [1, 2, 3]
        
        // Act
        for value in values {
            sut.record(value)
        }
        
        // Assert
        XCTAssertFalse(sut.isEmpty)
        XCTAssertEqual(sut.count, 3)
        XCTAssertEqual(sut.invocations, values)
        XCTAssertEqual(sut.first, 1)
        XCTAssertEqual(sut.last, 3)
    }
    
    func testGetWithValidIndex() throws {
        // Arrange
        let sut = Invocations<String>()
        let values = ["first", "second", "third"]
        values.forEach { sut.record($0) }
        
        // Act
        let result = sut.get(1)
        
        // Assert
        XCTAssertEqual(result, "second")
    }
    
    func testGetWithInvalidIndex() throws {
        // Arrange
        let sut = Invocations<String>()
        sut.record("test")
        
        // Act
        let result = sut.get(5)
        
        // Assert
        XCTAssertNil(result)
    }
    
    func testGetWithNegativeIndex() throws {
        // Arrange
        let sut = Invocations<String>()
        sut.record("test")
        
        // Act
        let result = sut.get(-1)
        
        // Assert
        XCTAssertNil(result)
    }
    
    func testGetFromEmptyInvocations() throws {
        // Arrange
        let sut = Invocations<String>()
        
        // Act
        let result = sut.get(0)
        
        // Assert
        XCTAssertNil(result)
    }
    
    func testRemoveAllFromEmptyInvocations() throws {
        // Arrange
        let sut = Invocations<String>()
        
        // Act
        sut.removeAll()
        
        // Assert
        XCTAssertTrue(sut.isEmpty)
        XCTAssertEqual(sut.count, 0)
        XCTAssertTrue(sut.invocations.isEmpty)
    }
    
    func testRemoveAllFromPopulatedInvocations() throws {
        // Arrange
        let sut = Invocations<String>()
        sut.record("test1")
        sut.record("test2")
        
        // Act
        sut.removeAll()
        
        // Assert
        XCTAssertTrue(sut.isEmpty)
        XCTAssertEqual(sut.count, 0)
        XCTAssertTrue(sut.invocations.isEmpty)
        XCTAssertNil(sut.first)
        XCTAssertNil(sut.last)
    }
    
    func testFirstAndLastWithSingleInvocation() throws {
        // Arrange
        let sut = Invocations<String>()
        let testValue = "single"
        
        // Act
        sut.record(testValue)
        
        // Assert
        XCTAssertEqual(sut.first, testValue)
        XCTAssertEqual(sut.last, testValue)
        XCTAssertEqual(sut.first, sut.last)
    }

    func testFromMultipleThreads() throws {

        // Arrange
        let sut = Invocations<Int>()

        let dispatchQueue = DispatchQueue(label: "InvocationsTests", attributes: [.concurrent, .initiallyInactive])

        let expectation = self.expectation(description: "testFromMultipleThreads")
        expectation.expectedFulfillmentCount = 1_000

        // Act
        for i in 0..<1_000 {
           dispatchQueue.async {
               sut.record(i)

               XCTAssertTrue(sut.invocations.contains(i))
               XCTAssertNotNil(sut.invocations)
               XCTAssertNotNil(sut.count)
               XCTAssertNotNil(sut.first)
               XCTAssertNotNil(sut.last)
               XCTAssertFalse(sut.isEmpty)

               expectation.fulfill()
           }
        }

        dispatchQueue.activate()
        wait(for: [expectation], timeout: 5.0)

        // Assert
        XCTAssertEqual(sut.invocations.count, 1_000)
    }

    func testRemoveAllAfterAddingRecords() throws {

        // Arrange
        let sut = Invocations<Void>()

        let dispatchQueue = DispatchQueue(label: "InvocationsTests", attributes: [.concurrent, .initiallyInactive])

        let expectation = self.expectation(description: "testFromMultipleThreads")
        expectation.expectedFulfillmentCount = 1_000

        // Act
        for _ in 0..<1_000 {
           dispatchQueue.async {
               // Act
               for _ in 0..<10 {
                   sut.record(Void())
               }

               sut.removeAll()

               expectation.fulfill()
           }
        }

        dispatchQueue.activate()

        wait(for: [expectation], timeout: 5.0)

        // Assert
        XCTAssertTrue(sut.invocations.isEmpty)

    }

}
