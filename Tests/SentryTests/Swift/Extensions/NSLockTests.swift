import Nimble
@testable import Sentry
import XCTest

final class NSLockTests: XCTestCase {

    func testLockForIncrement() throws {
        let lock = NSLock()
        
        var value = 0
        
        testConcurrentModifications(asyncWorkItems: 10, writeLoopCount: 9, writeWork: { _ in
            lock.synchronized {
                value += 1
            }
        })
        
        expect(value) == 100
    }
    
    func testUnlockWhenThrowing() throws {
        let lock = NSLock()
        
        let errorMessage = "It's broken"
        do {
            try lock.synchronized {
                throw NSLockError.runtimeError(errorMessage)
            }
        } catch NSLockError.runtimeError(let actualErrorMessage) {
            expect(actualErrorMessage) == errorMessage
        }
        
        let expectation = expectation(description: "Lock should be non blocking")
        
        DispatchQueue.global().async {
            lock.synchronized {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 0.1)
    }

    enum NSLockError: Error {
        case runtimeError(String)
    }
}
