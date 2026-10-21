#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@testable import Sentry
#endif
import Foundation
import XCTest

final class TestLogOutput {
    
    private let logsToConsole: Bool
    private let thread: Thread?
    private var _loggedMessages: [String] = []
    private let lock = NSLock()

    // Opt in to isolation for synchronous tests; asynchronous tests still capture every thread.
    init(logsToConsole: Bool = true, thread: Thread? = nil) {
        self.logsToConsole = logsToConsole
        self.thread = thread
    }

    var loggedMessages: [String] {
        lock.synchronized {
            return _loggedMessages
        }
    }
    
    func log(_ message: String) {
        if let thread, thread !== Thread.current {
            return
        }
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
    
    func testLog_whenThreadIsSelected_shouldIgnoreOtherThreads() {
        // -- Arrange --
        let sut = TestLogOutput(logsToConsole: false, thread: Thread.current)
        let completed = expectation(description: "Background log completed")

        // -- Act --
        sut.log("Selected thread")
        DispatchQueue.global().async {
            sut.log("Other thread")
            completed.fulfill()
        }
        wait(for: [completed], timeout: 5.0)

        // -- Assert --
        XCTAssertEqual(sut.loggedMessages, ["Selected thread"])
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
