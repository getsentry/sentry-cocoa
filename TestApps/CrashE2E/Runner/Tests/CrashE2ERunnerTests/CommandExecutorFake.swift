@testable import CrashE2ERunner
import Foundation
import XCTest

final class CommandExecutorFake: CommandExecuting {
    struct Call {
        let tool: String
        let arguments: [String]
        let captureOutput: Bool
        let timeout: TimeInterval?
        let allowFailure: Bool

        func isCommand(_ tool: String, _ argumentPrefix: [String] = []) -> Bool {
            self.tool == tool && arguments.starts(with: argumentPrefix)
        }

        func result(status: Int32 = 0, stdout: String = "", stderr: String = "", timedOut: Bool = false) -> ProcessResult {
            ProcessResult(tool: tool, arguments: arguments, terminationStatus: status, terminationReason: .exit,
                          stdout: stdout, stderr: stderr, timedOut: timedOut, timeout: timeout)
        }
    }

    private(set) var calls: [Call] = []
    var handler: (Call) throws -> ProcessResult = { call in
        XCTFail("Unexpected command: \(call.tool) \(call.arguments)")
        throw CrashE2EFailure(message: "Unexpected command")
    }

    func execute(_ tool: String, _ arguments: [String], captureOutput: Bool,
                 timeout: TimeInterval?, allowFailure: Bool) throws -> ProcessResult {
        let call = Call(tool: tool, arguments: arguments, captureOutput: captureOutput,
                        timeout: timeout, allowFailure: allowFailure)
        calls.append(call)

        let result = try handler(call)

        guard allowFailure || result.succeeded else {
            throw CrashE2EFailure(message: "Command failed with \(result.summary): \(result.commandLine)\n\(result.stderr)")
        }

        return result
    }
}
