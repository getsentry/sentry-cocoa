import Foundation

class TestLogOutput: SentryLogOutput {
    
    private let queue = DispatchQueue(label: "TestLogOutput", attributes: .concurrent)
    
    private var _loggedMessages: [String] = []
    
    var loggedMessages: [String] {
        get {
            queue.sync {
                return _loggedMessages
            }
        }
    }
    
    override func log(_ message: String) {
        super.log(message)
        queue.async(flags: .barrier) {
            self._loggedMessages.append(message)
        }
    }
}

class TestLogOutPutTests: XCTestCase {
    
    func testLoggingFromMulitpleThreads() {
        let sut = TestLogOutput()
        
        let queue = DispatchQueue(label: "TestLogOutPutTests", qos: .userInteractive, attributes: [.concurrent, .initiallyInactive])
        let group = DispatchGroup()
        
        for _ in 0...2 {
            group.enter()
            queue.async {
                
                for i in 0...1_000 {
                    sut.log("Some message \(i)")
                }
                
                XCTAssertNotNil(sut.loggedMessages)
                
                group.leave()
            }
        }
        
        queue.activate()
        group.waitWithTimeout(timeout: 500)
    }
}
