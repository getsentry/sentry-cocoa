@testable import CrashE2ERunner
import Foundation
import XCTest

/// Small subprocess integration checks for the production adapter, not orchestration tests.
final class CommandExecutingTests: XCTestCase {
    func testRun_whenCapturingOutput_shouldPreserveArgumentsAndOutput() throws {
        // -- Arrange --
        let executor: any CommandExecuting = ProcessRunner(environment: ["PATH": "/usr/bin:/bin"])
        let arguments = ["%s", "one argument with spaces\nand a newline"]

        // -- Act --
        let result = try executor.run("printf", arguments, captureOutput: true, timeout: 5)

        // -- Assert --
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.stdout, "one argument with spaces\nand a newline")
        XCTAssertEqual(result.stderr, "")
        XCTAssertEqual(result.tool, "printf")
        XCTAssertEqual(result.arguments, arguments)
    }

    func testRun_whenFailureIsAllowed_shouldReturnNonzeroExitStatus() throws {
        // -- Arrange --
        let executor: any CommandExecuting = ProcessRunner()

        // -- Act --
        let result = try executor.run("/usr/bin/false", [], captureOutput: true, allowFailure: true)

        // -- Assert --
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.terminationReason, .exit)
        XCTAssertEqual(result.terminationStatus, 1)
        XCTAssertFalse(result.timedOut)
    }

    func testRun_whenFailureIsNotAllowed_shouldThrow() {
        // -- Arrange --
        let executor: any CommandExecuting = ProcessRunner()

        // -- Act & Assert --
        XCTAssertThrowsError(try executor.run("/usr/bin/false", [], captureOutput: true)) { error in
            XCTAssertTrue(String(describing: error).contains("Command failed with status 1"))
        }
    }

    func testRun_whenDeadlineExpires_shouldReturnTimedOutResult() throws {
        // -- Arrange --
        let executor: any CommandExecuting = ProcessRunner()

        // -- Act --
        let result = try executor.run("/bin/sleep", ["30"], captureOutput: true, timeout: 0.01, allowFailure: true)

        // -- Assert --
        XCTAssertTrue(result.timedOut)
        XCTAssertFalse(result.succeeded)
        XCTAssertEqual(result.timeout, 0.01)
    }
}
