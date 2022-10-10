import Foundation

class TestLogOutput: SentryLogOutput {
    var loggedMessages: [String] = []
    override func log(_ message: String) {
        loggedMessages.append(message)
    }
}
