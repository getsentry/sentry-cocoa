import XCTest

extension XCTestCase {
    func delay(seconds: TimeInterval) {
        let exp = expectation(description: "Waiting for \(seconds) seconds")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: seconds + 1)
    }
}
