import Foundation
@testable import Sentry
import XCTest

final class TestLogOutput {
    
    private let queue = DispatchQueue(label: "TestLogOutput", attributes: .concurrent)
    
    private var _loggedMessages: [String] = []
    
    var logsToConsole: Bool = true

    var loggedMessages: [String] {
        queue.sync {
            return _loggedMessages
        }
    }
    
    func log(_ message: String) {
        if logsToConsole {
            print(message)
        }
        queue.async(flags: .barrier) {
            self._loggedMessages.append(message)
        }
    }
}

class TestLogOutPutTests: XCTestCase {
    
    func testLoggingFromMulitpleThreads() {
        let sut = TestLogOutput()
        sut.logsToConsole = false
        testConcurrentModifications(writeWork: { i in
            sut.log("Some message \(i)")
        }, readWork: {
            XCTAssertNotNil(sut.loggedMessages)
        })
    }
}
