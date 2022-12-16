import Foundation

class TestLogOutput: SentryLogOutput {
    var loggedMessages: [String] = []
    override func log(_ message: String) {
        super.log(message)
        loggedMessages.append(message)
    }
}
