@testable import CrashE2ERunner
import Darwin
import Foundation
import XCTest

final class ProcessExitObserverTests: XCTestCase {
    func testWait_whenProcessIsAlive_shouldTimeOut() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let observer = try ProcessExitObserver(processIdentifier: process.processIdentifier)

        // -- Act --
        let stopped = try observer.wait(timeout: 0.01)

        // -- Assert --
        XCTAssertFalse(stopped)
        XCTAssertTrue(process.isRunning)
    }

    func testWait_whenProcessExitsAfterRegistration_shouldReturnTrue() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let observer = try ProcessExitObserver(processIdentifier: process.processIdentifier)

        // -- Act --
        process.terminate()
        let stopped = try observer.wait(timeout: 5)

        // -- Assert --
        XCTAssertTrue(stopped)
        XCTAssertTrue(try observer.wait(timeout: 0), "Exit must stay latched even after the one-shot event is consumed")
    }

    func testWait_whenProcessExitedBeforeRegistration_shouldReturnTrue() throws {
        // -- Arrange --
        let process = try startProcess()
        stopProcess(process)

        // -- Act --
        let observer = try ProcessExitObserver(processIdentifier: process.processIdentifier)

        // -- Assert --
        XCTAssertTrue(try observer.wait(timeout: 0))
    }

    func testWait_whenProcessIsUnreaped_shouldReturnTrue() throws {
        // -- Arrange --
        // Do not use Foundation.Process: it reaps children automatically.
        let executable = try XCTUnwrap(strdup("/usr/bin/true"))
        defer { free(executable) }

        let arguments: [UnsafeMutablePointer<CChar>?] = [executable, nil]
        var pid: pid_t = 0
        let result = try arguments.withUnsafeBufferPointer { buffer in
            let baseAddress = try XCTUnwrap(buffer.baseAddress)
            return posix_spawn(&pid, executable, nil, nil, baseAddress, nil)
        }
        XCTAssertEqual(result, 0)
        guard result == 0 else { return }
        defer {
            var status: Int32 = 0
            _ = waitpid(pid, &status, 0)
        }

        let firstObserver = try ProcessExitObserver(processIdentifier: pid)
        XCTAssertTrue(try firstObserver.wait(timeout: 5))

        // -- Act --
        let observer = try ProcessExitObserver(processIdentifier: pid)

        // -- Assert --
        XCTAssertTrue(try observer.wait(timeout: 0), "A zombie is terminated even though kill(pid, 0) can succeed")
    }

    func testInit_whenPIDIsNotPositive_shouldThrow() {
        // -- Arrange --
        let invalidPIDs: [Int32] = [0, -1]

        // -- Act & Assert --
        for pid in invalidPIDs {
            XCTAssertThrowsError(try ProcessExitObserver(processIdentifier: pid))
        }
    }

    func testLaunchedProcessIdentifier_whenOutputMatchesBundle_shouldParsePID() throws {
        // -- Arrange --
        let bundleID = Reporter.ksCrash.iOSBundleID
        let stdout = "simctl informational output\n\(bundleID): 12345\n"

        // -- Act --
        let pid = try ProcessExitObserver.launchedProcessIdentifier(stdout: stdout, bundleID: bundleID)

        // -- Assert --
        XCTAssertEqual(pid, 12_345)
    }

    func testLaunchedProcessIdentifier_whenOutputIsInvalid_shouldThrow() {
        // -- Arrange --
        let bundleID = Reporter.ksCrash.iOSBundleID
        let outputs = ["", "other.bundle: 123", "\(bundleID): 0", "\(bundleID): -1",
                       "\(bundleID): nope", "\(bundleID): 123 extra", "\(bundleID): 999999999999",
                       "\(bundleID): 123\n\(bundleID): 456"]

        // -- Act & Assert --
        for stdout in outputs {
            XCTAssertThrowsError(try ProcessExitObserver.launchedProcessIdentifier(stdout: stdout, bundleID: bundleID), stdout)
        }
    }

    private func startProcess() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["30"]

        try process.run()

        return process
    }

    private func stopProcess(_ process: Process) {
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
    }
}
