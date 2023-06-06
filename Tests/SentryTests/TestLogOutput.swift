import Foundation

class TestLogOutput: SentryLogOutput {
    
    private let queue = DispatchQueue(label: "TestLogOutput", attributes: .concurrent)
    
    private var _loggedMessages: [String] = []
    
    var callSuperWhenLogging = true
    
    var loggedMessages: [String] {
        queue.sync {
            return _loggedMessages
        }
    }
    
    override func log(_ message: String) {
        if callSuperWhenLogging {
            super.log(message)
        }
        queue.async(flags: .barrier) {
            self._loggedMessages.append(message)
        }
    }
}

class TestLogOutPutTests: XCTestCase {
    
    func testLoggingFromMulitpleThreads() {
        let sut = TestLogOutput()
        sut.callSuperWhenLogging = false
        testConcurrentModifications(writeWork: { i in
            sut.log("Some message \(i)")
        }, readWork: {
            XCTAssertNotNil(sut.loggedMessages)
        })
    }
}
