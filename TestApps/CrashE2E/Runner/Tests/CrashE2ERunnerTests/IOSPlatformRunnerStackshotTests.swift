@testable import CrashE2ERunner
import Foundation
import XCTest

final class IOSPlatformRunnerStackshotTests: XCTestCase {
    func testWaitForAppToStop_whenCaptureSucceeds_shouldSaveSymbolicatedStacksWithoutChangingDeadline() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier)
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])

        let directory = try XCTUnwrap(fixture.runner.launchArtifacts)
        let output = directory.appendingPathComponent("stackshot.spindump")
        let defaultHandler = fixture.commands.handler
        fixture.commands.handler = { call in
            if call.isCommand("sudo", ["-n", "/usr/sbin/spindump"]) {
                try "symbolicated stacks and binary data\n".write(to: output, atomically: true, encoding: .utf8)
                return call.result()
            }
            return try defaultHandler(call)
        }

        // -- Act --
        let stopped = try fixture.runner.waitForAppToStop(timeout: 0)

        // -- Assert --
        XCTAssertFalse(stopped)

        let capture = try XCTUnwrap(fixture.commands.calls.first { $0.tool == "sudo" })
        XCTAssertEqual(capture.arguments, ["-n", "/usr/sbin/spindump", String(process.processIdentifier),
                                           "2", "10", "-onlyTarget", "-o", output.path, "-timelimit", "60"])
        XCTAssertNil(capture.timeout, "Use spindump's own budget rather than killing its sudo wrapper")
        XCTAssertEqual(try String(contentsOf: output, encoding: .utf8), "symbolicated stacks and binary data\n")
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("stackshot-unavailable.log").path))
        XCTAssertFalse(fixture.commands.calls.contains { $0.tool == "sample" })
    }

    func testWaitForAppToStop_whenSudoIsUnavailable_shouldPreserveFailureAndAllowCleanup() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier, onTerminate: { process.terminate() })
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])
        let directory = try XCTUnwrap(fixture.runner.launchArtifacts)
        let defaultHandler = fixture.commands.handler
        fixture.commands.handler = { call in
            if call.isCommand("sudo") { return call.result(status: 1, stderr: "sudo: a password is required") }
            return try defaultHandler(call)
        }

        // -- Act --
        let stopped = try fixture.runner.waitForAppToStop(timeout: 0)
        try fixture.runner.terminateApp()

        // -- Assert --
        XCTAssertFalse(stopped)
        XCTAssertNil(fixture.runner.appProcess)

        let unavailable = try String(contentsOf: directory.appendingPathComponent("stackshot-unavailable.log"), encoding: .utf8)
        XCTAssertTrue(unavailable.contains("sudo: a password is required"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("timeout.log").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("host-load.log").path))
        XCTAssertFalse(fixture.commands.calls.contains { $0.tool == "sample" }, "No fallback to an externally killed sampler")
    }

    func testWaitForAppToStop_whenCollectorWritesNoReport_shouldRecordMissingEvidence() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier)
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])

        let defaultHandler = fixture.commands.handler
        fixture.commands.handler = { call in
            if call.isCommand("sudo") { return call.result() }
            return try defaultHandler(call)
        }

        // -- Act --
        let stopped = try fixture.runner.waitForAppToStop(timeout: 0)

        // -- Assert --
        XCTAssertFalse(stopped)

        let directory = try XCTUnwrap(fixture.runner.launchArtifacts)
        let unavailable = try String(contentsOf: directory.appendingPathComponent("stackshot-unavailable.log"), encoding: .utf8)
        XCTAssertTrue(unavailable.contains("no nonempty stackshot was saved"))
    }

    func testWaitForAppToStop_whenCollectorCannotStart_shouldPreserveDeadlineAndAllowCleanup() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier, onTerminate: { process.terminate() })
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])

        let defaultHandler = fixture.commands.handler
        fixture.commands.handler = { call in
            if call.isCommand("sudo") { throw CocoaError(.fileReadNoPermission) }
            return try defaultHandler(call)
        }

        // -- Act --
        let stopped = try fixture.runner.waitForAppToStop(timeout: 0)
        try fixture.runner.terminateApp()

        // -- Assert --
        XCTAssertFalse(stopped)
        XCTAssertNil(fixture.runner.appProcess)

        let directory = try XCTUnwrap(fixture.runner.launchArtifacts)
        let unavailable = try String(contentsOf: directory.appendingPathComponent("stackshot-unavailable.log"), encoding: .utf8)
        XCTAssertTrue(unavailable.contains("Could not start stackshot collection"))
    }

    func testWaitForAppToStop_whenCollectorFailsWithReport_shouldRetainTheEvidence() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier)
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])

        let directory = try XCTUnwrap(fixture.runner.launchArtifacts)
        let output = directory.appendingPathComponent("stackshot.spindump")
        let defaultHandler = fixture.commands.handler
        fixture.commands.handler = { call in
            if call.isCommand("sudo") {
                try "partial report".write(to: output, atomically: true, encoding: .utf8)
                return call.result(status: 1, stderr: "collector failed")
            }
            return try defaultHandler(call)
        }

        // -- Act --
        let stopped = try fixture.runner.waitForAppToStop(timeout: 0)

        // -- Assert --
        XCTAssertFalse(stopped)
        XCTAssertEqual(try String(contentsOf: output, encoding: .utf8), "partial report")

        let unavailable = try String(contentsOf: directory.appendingPathComponent("stackshot-unavailable.log"), encoding: .utf8)
        XCTAssertTrue(unavailable.contains("retaining the report"))
    }

    private func startProcess() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["60"]
        try process.run()
        return process
    }

    private func stopProcess(_ process: Process) {
        if process.isRunning { process.terminate() }
        process.waitUntilExit()
    }
}
