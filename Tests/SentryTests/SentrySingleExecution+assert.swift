import Foundation
import XCTest

extension XCTestCase {

    func assertRaceConditon(target: SentrySingleExecution, firstCall: @escaping () -> Void, subsequentCall: () -> Void) {
        let semaphore = DispatchSemaphore(value: 0)

        let beginOFExecuteExpectation = expectation(description: "Will Execute Begin")
        let endOFExecuteExpectation = expectation(description: "Will Execute End")
        let willSkipExpectation = expectation(description: "WillSkip")

        target.willExecute = {
            beginOFExecuteExpectation.fulfill()
            //Hold the execution to test race condition
            semaphore.wait()
        }

        target.willSkip = {
            willSkipExpectation.fulfill()
            semaphore.signal()
        }

        DispatchQueue.global().async {
            firstCall()
            endOFExecuteExpectation.fulfill()
        }

        wait(for: [beginOFExecuteExpectation], timeout: 1)

        subsequentCall()

        wait(for: [endOFExecuteExpectation, willSkipExpectation], timeout: 1)
    }

}
