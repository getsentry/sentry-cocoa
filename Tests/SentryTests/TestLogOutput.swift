import Foundation
@testable import Sentry
import XCTest

final class TestLogOutput {
    
    private let logsToConsole: Bool
    private var _loggedMessages: [String] = []
    private let lock = NSLock()

    init(logsToConsole: Bool = true) {
        self.logsToConsole = logsToConsole
    }

    var loggedMessages: [String] {
        lock.synchronized {
            return _loggedMessages
        }
    }
    
    func log(_ message: String) {
        if logsToConsole {
            print(message)
        }
        lock.synchronized {
            self._loggedMessages.append(message)
        }
    }
}

class TestLogOutPutTests: XCTestCase {
    
    func testLoggingFromMultipleThreads() {
        // Arrange
        let sut = TestLogOutput(logsToConsole: false)

        let queue = DispatchQueue(label: "testLoggingFromMultipleThreads", attributes: [.concurrent])
        let expectation = expectation(description: "Logging from multiple threads")

        let iterations = 100
        expectation.expectedFulfillmentCount = iterations * 2

        // Act
        for i in 0..<iterations {

            queue.async {
                sut.log("Message \(i)")
                expectation.fulfill()
            }

            queue.async {
                XCTAssertNotNil(sut.loggedMessages)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Assert
        XCTAssertEqual(sut.loggedMessages.count, iterations)
    }
    
    func testInitialState_LoggedMessagesIsEmpty() {
        // Arrange
        let sut = TestLogOutput(logsToConsole: false)
        
        // Act
        let messages = sut.loggedMessages
        
        // Assert
        XCTAssertTrue(messages.isEmpty)
        XCTAssertEqual(messages.count, 0)
    }
    
    func testLogSingleMessage_MessageIsStored() {
        // Arrange
        let sut = TestLogOutput(logsToConsole: false)
        let testMessage = "Test message"
        
        // Act
        sut.log(testMessage)
        
        // Assert
        let messages = sut.loggedMessages
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first, testMessage)
    }
    
    func testLogMultipleMessages_AllMessagesAreStoredInOrder() {
        // Arrange
        let sut = TestLogOutput(logsToConsole: false)
        let testMessages = ["First message", "Second message", "Third message"]
        
        // Act
        for message in testMessages {
            sut.log(message)
        }
        
        // Assert
        let messages = sut.loggedMessages
        XCTAssertEqual(messages.count, testMessages.count)
        XCTAssertEqual(messages, testMessages)
    }
    
    func testLogEmptyString_EmptyStringIsStored() {
        // Arrange
        let sut = TestLogOutput(logsToConsole: false)
        let emptyMessage = ""
        
        // Act
        sut.log(emptyMessage)
        
        // Assert
        let messages = sut.loggedMessages
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first, emptyMessage)
    }
    
    func testLogAfterMultipleReads_MessagesAreConsistent() {
        // Arrange
        let sut = TestLogOutput(logsToConsole: false)
        let firstMessage = "First message"
        let secondMessage = "Second message"
        
        // Act
        sut.log(firstMessage)
        let messagesAfterFirst = sut.loggedMessages
        sut.log(secondMessage)
        let messagesAfterSecond = sut.loggedMessages
        
        // Assert
        XCTAssertEqual(messagesAfterFirst.count, 1)
        XCTAssertEqual(messagesAfterFirst.first, firstMessage)
        XCTAssertEqual(messagesAfterSecond.count, 2)
        XCTAssertEqual(messagesAfterSecond, [firstMessage, secondMessage])
    }
}
