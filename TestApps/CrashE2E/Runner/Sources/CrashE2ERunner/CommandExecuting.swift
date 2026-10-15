import Foundation

/// The synchronous command interfaces used by iOS orchestration. This is distinc from process 
/// observation: a command's result says nothing about the lifecycle of the app it launched.
protocol CommandExecuting {
    func execute(_ tool: String, _ arguments: [String], captureOutput: Bool,
                 timeout: TimeInterval?, allowFailure: Bool) throws -> ProcessResult
}

extension CommandExecuting {
    @discardableResult
    func run(_ tool: String, _ arguments: [String], captureOutput: Bool = false,
             timeout: TimeInterval? = nil, allowFailure: Bool = false) throws -> ProcessResult {
        try execute(tool, arguments, captureOutput: captureOutput, timeout: timeout, allowFailure: allowFailure)
    }
}

extension ProcessRunner: CommandExecuting {
    func execute(_ tool: String, _ arguments: [String], captureOutput: Bool,
                 timeout: TimeInterval?, allowFailure: Bool) throws -> ProcessResult {
        try run(tool, arguments, workingDirectory: nil, captureOutput: captureOutput,
                timeout: timeout, allowFailure: allowFailure)
    }
}
