import Foundation
import XCTest

class SentryTestThreadWrapper: SentryThreadWrapper {
    
    var threadFinishedExpectation = XCTestExpectation(description: "Thread Finished Expectation")
    var threads: Set<UUID> = Set()
    var threadStartedInvocations = Invocations<UUID>()
    var threadFinishedInvocations = Invocations<UUID>()
    
    override func sleep(forTimeInterval timeInterval: TimeInterval) {
        // Don't sleep. Do nothing.
    }

    override func threadStarted(_ threadID: UUID) {
        threadStartedInvocations.record(threadID)
        threads.insert(threadID)
    }
    
    override func threadFinished(_ threadID: UUID) {
        threadFinishedInvocations.record(threadID)
        threads.remove(threadID)
        threadFinishedExpectation.fulfill()
    }

}
