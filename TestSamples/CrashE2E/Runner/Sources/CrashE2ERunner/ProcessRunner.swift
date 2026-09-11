import Darwin
import Foundation

struct ProcessResult {
    let tool: String
    let arguments: [String]
    let terminationStatus: Int32
    let terminationReason: Process.TerminationReason
    let stdout: String
    let stderr: String
    let timedOut: Bool
    let timeout: TimeInterval?

    var succeeded: Bool {
        !timedOut && terminationReason == .exit && terminationStatus == 0
    }

    var summary: String {
        if timedOut {
            return timeout.map { "timeout after \(Int($0))s" } ?? "timeout"
        }

        switch terminationReason {
        case .exit:
            return "status \(terminationStatus)"
        case .uncaughtSignal:
            return "signal \(terminationStatus)"
        @unknown default:
            return "unknown termination \(terminationStatus)"
        }
    }

    var commandLine: String {
        ([tool] + arguments).map(shellQuote).joined(separator: " ")
    }
}

private func shellQuote(_ value: String) -> String {
    guard !value.isEmpty else { return "''" }
    let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+-./:=,@%")
    if value.unicodeScalars.allSatisfy({ safe.contains($0) }) {
        return value
    }
    return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

private struct ProcessIOContext {
    var openHandles: [FileHandle] = []
    var stdoutURL: URL?
    var stderrURL: URL?
    var temporaryDirectory: URL?

    func closeOpenHandles() {
        for handle in openHandles {
            handle.closeFile()
        }
    }
}

/// A process started with `ProcessRunner.start` that the caller can signal before waiting on it.
final class RunningProcess {
    fileprivate let process: Process
    fileprivate let ioContext: ProcessIOContext
    fileprivate let semaphore: DispatchSemaphore
    fileprivate let tool: String
    fileprivate let arguments: [String]

    fileprivate init(process: Process, ioContext: ProcessIOContext, semaphore: DispatchSemaphore,
                     tool: String, arguments: [String]) {
        self.process = process
        self.ioContext = ioContext
        self.semaphore = semaphore
        self.tool = tool
        self.arguments = arguments
    }

    var processIdentifier: Int32 { process.processIdentifier }
    var isRunning: Bool { process.isRunning }
}

final class ProcessRunner {
    private let fileManager = FileManager.default
    private let baseEnvironment: [String: String]
    private let pathDirectories: [String]

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.baseEnvironment = environment
        let defaultPATH = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        self.pathDirectories = (environment["PATH"] ?? defaultPATH)
            .split(separator: ":")
            .map(String.init)
    }

    func requireTool(_ name: String) throws {
        _ = try executableURL(for: name)
    }

    func runOutput(_ tool: String, _ arguments: [String], workingDirectory: URL? = nil,
                   environment additionalEnvironment: [String: String] = [:], allowFailure: Bool = false) throws -> String {
        let result = try run(tool, arguments, workingDirectory: workingDirectory,
                             environment: additionalEnvironment, captureOutput: true,
                             allowFailure: allowFailure)
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    func run(_ tool: String, _ arguments: [String], workingDirectory: URL? = nil,
             environment additionalEnvironment: [String: String] = [:], captureOutput: Bool = false,
             outputFile: URL? = nil, timeout: TimeInterval? = nil,
             allowFailure: Bool = false) throws -> ProcessResult {
        let running = try start(tool, arguments, workingDirectory: workingDirectory,
                                environment: additionalEnvironment, captureOutput: captureOutput,
                                outputFile: outputFile)
        let result = wait(for: running, timeout: timeout)
        try validate(result, allowFailure: allowFailure)
        return result
    }

    /// Starts the process without waiting for it. Callers must finish with `wait(for:timeout:)`
    /// so output handles are closed and the termination status is collected.
    func start(_ tool: String, _ arguments: [String], workingDirectory: URL? = nil,
               environment additionalEnvironment: [String: String] = [:], captureOutput: Bool = false,
               outputFile: URL? = nil) throws -> RunningProcess {
        let process = try makeProcess(tool, arguments, workingDirectory, additionalEnvironment)
        let ioContext = try configureOutput(for: process, captureOutput: captureOutput, outputFile: outputFile)
        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }

        do {
            try process.run()
        } catch {
            ioContext.closeOpenHandles()
            removeTemporaryDirectory(for: ioContext)
            throw CrashE2EFailure(message: "Failed to run \(tool): \(error)")
        }

        return RunningProcess(process: process, ioContext: ioContext, semaphore: semaphore,
                              tool: tool, arguments: arguments)
    }

    /// Waits for a process started with `start`. On timeout the process is terminated and the
    /// result is flagged as timed out.
    func wait(for running: RunningProcess, timeout: TimeInterval?) -> ProcessResult {
        let timedOut = wait(for: running.process, semaphore: running.semaphore, timeout: timeout)
        running.process.terminationHandler = nil
        running.ioContext.closeOpenHandles()
        return resultFor(running.process, tool: running.tool, arguments: running.arguments,
                         ioContext: running.ioContext, timedOut: timedOut, timeout: timeout)
    }

    private func makeProcess(_ tool: String, _ arguments: [String], _ workingDirectory: URL?,
                             _ additionalEnvironment: [String: String]) throws -> Process {
        let process = Process()
        process.executableURL = try executableURL(for: tool)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        process.environment = baseEnvironment.merging(additionalEnvironment) { _, new in new }
        return process
    }

    private func configureOutput(for process: Process, captureOutput: Bool,
                                 outputFile: URL?) throws -> ProcessIOContext {
        if let outputFile {
            return try configureFileOutput(for: process, outputFile: outputFile)
        }
        if captureOutput {
            return try configureCapturedOutput(for: process)
        }
        return ProcessIOContext()
    }

    private func configureFileOutput(for process: Process, outputFile: URL) throws -> ProcessIOContext {
        try fileManager.ensureDirectory(at: outputFile.deletingLastPathComponent())
        fileManager.createFile(atPath: outputFile.path, contents: nil)
        let handle = try FileHandle(forWritingTo: outputFile)
        process.standardOutput = handle
        process.standardError = handle
        return ProcessIOContext(openHandles: [handle])
    }

    private func configureCapturedOutput(for process: Process) throws -> ProcessIOContext {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("crash-e2e-runner-\(UUID().uuidString)", isDirectory: true)
        try fileManager.ensureDirectory(at: directory)

        let stdoutURL = directory.appendingPathComponent("stdout")
        let stderrURL = directory.appendingPathComponent("stderr")
        fileManager.createFile(atPath: stdoutURL.path, contents: nil)
        fileManager.createFile(atPath: stderrURL.path, contents: nil)

        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle
        return ProcessIOContext(openHandles: [stdoutHandle, stderrHandle], stdoutURL: stdoutURL,
                                stderrURL: stderrURL, temporaryDirectory: directory)
    }

    private func wait(for process: Process, semaphore: DispatchSemaphore, timeout: TimeInterval?) -> Bool {
        guard let timeout else {
            semaphore.wait()
            return false
        }

        guard semaphore.wait(timeout: .now() + timeout) == .timedOut else { return false }
        process.terminate()
        if semaphore.wait(timeout: .now() + 5) == .timedOut, process.isRunning {
            Darwin.kill(process.processIdentifier, SIGKILL)
            _ = semaphore.wait(timeout: .now() + 5)
        }
        return true
    }

    private func resultFor(_ process: Process, tool: String, arguments: [String],
                           ioContext: ProcessIOContext, timedOut: Bool,
                           timeout: TimeInterval?) -> ProcessResult {
        let stdout = ioContext.stdoutURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        let stderr = ioContext.stderrURL.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
        removeTemporaryDirectory(for: ioContext)
        return ProcessResult(tool: tool, arguments: arguments,
                             terminationStatus: process.terminationStatus,
                             terminationReason: process.terminationReason,
                             stdout: stdout, stderr: stderr,
                             timedOut: timedOut, timeout: timeout)
    }

    private func validate(_ result: ProcessResult, allowFailure: Bool) throws {
        guard !allowFailure && !result.succeeded else { return }
        var message = "Command failed with \(result.summary): \(result.commandLine)"
        if !result.stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            message += "\n\(result.stderr)"
        }
        throw CrashE2EFailure(message: message)
    }

    private func removeTemporaryDirectory(for ioContext: ProcessIOContext) {
        guard let temporaryDirectory = ioContext.temporaryDirectory else { return }
        try? fileManager.removeItem(at: temporaryDirectory)
    }

    private func executableURL(for tool: String) throws -> URL {
        if tool.contains("/") {
            guard fileManager.isExecutableFile(atPath: tool) else {
                throw CrashE2EFailure(message: "Required executable not found: \(tool)")
            }
            return URL(fileURLWithPath: tool)
        }

        for directory in pathDirectories {
            let path = URL(fileURLWithPath: directory).appendingPathComponent(tool).path
            if fileManager.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        throw CrashE2EFailure(message: "Required tool not found on PATH: \(tool)")
    }
}
