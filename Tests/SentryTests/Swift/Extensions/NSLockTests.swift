@testable import Sentry
import XCTest

final class NSLockTests: XCTestCase {

    func testLockForIncrement() throws {
        let lock = NSLock()
        
        var value = 0
        
        testConcurrentModifications(asyncWorkItems: 10, writeLoopCount: 9, writeWork: { _ in
            let returnValue: Int = lock.synchronized {
                value += 1
                return 10
            }
            XCTAssertEqual(returnValue, 10)
            
            lock.synchronized {
                value += 1
            }
        })
        
        XCTAssertEqual(value, 200)
    }
    
    func testUnlockWhenThrowing() throws {
        let lock = NSLock()
        
        let errorMessage = "It's broken"
        do {
            try lock.synchronized {
                throw NSLockError.runtimeError(errorMessage)
            }
        } catch NSLockError.runtimeError(let actualErrorMessage) {
            XCTAssertEqual(actualErrorMessage, errorMessage)
        }
        
        let expectation = expectation(description: "Lock should be non blocking")
        
        DispatchQueue.global().async {
            lock.synchronized {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 0.1)
    }
    
    func testCheckFlagIsFalse() {
        var flag = false
        var executed = false
        let lock = NSLock()
        _ = lock.checkFlag(flag: &flag) {
            executed = true
        }
        XCTAssertTrue(executed)
        XCTAssertTrue(flag)
    }
    
    func testCheckFlagIsTrue() {
        var flag = true
        var skipped = true
        let lock = NSLock()
        _ = lock.checkFlag(flag: &flag) {
            skipped = false
        }
        XCTAssertTrue(skipped)
        XCTAssertTrue(flag)
    }
    
    func testStressFlag() {
        let lock = NSLock()
        var flag = false
        var value = 0
        
        testConcurrentModifications(asyncWorkItems: 100, writeLoopCount: 9, writeWork: { _ in
            _ = lock.checkFlag(flag: &flag) { value += 1 }
        })
        
        XCTAssertEqual(value, 1)
    }

    enum NSLockError: Error {
        case runtimeError(String)
    }
}
