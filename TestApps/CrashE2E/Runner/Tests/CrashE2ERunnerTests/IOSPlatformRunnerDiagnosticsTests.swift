@testable import CrashE2ERunner
import Foundation
import XCTest

final class IOSPlatformRunnerDiagnosticsTests: XCTestCase {
    func testRunScenarios_whenSetupTimesOut_shouldRecordStatePhaseAndActualCommandTermination() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0, scenarios: [.ignoredSignal])
        defer { fixture.remove() }

        let defaultHandler = fixture.commands.handler
        fixture.commands.handler = { call in
            if call.isCommand("xcrun", ["simctl", "get_app_container"]) {
                return ProcessResult(tool: call.tool, arguments: call.arguments, terminationStatus: 9,
                                     terminationReason: .uncaughtSignal, stdout: "", stderr: "simulator unavailable",
                                     timedOut: true, timeout: call.timeout)
            }
            return try defaultHandler(call)
        }

        // -- Act --
        XCTAssertThrowsError(try fixture.runner.runScenarios()) { error in
            XCTAssertTrue(error is SimulatorCommandFailure)
        }

        // -- Assert --
        XCTAssertEqual(fixture.runner.launchCount, 0)
        let artifacts = fixture.runner.config.artifactsDir
        let failure = try String(contentsOf: artifacts.appendingPathComponent("ios-ignored-signal-failure.log"), encoding: .utf8)
        XCTAssertTrue(failure.contains("Phase: scenario setup"))
        XCTAssertTrue(failure.contains("App state: known stopped"))
        XCTAssertTrue(failure.contains("infrastructure failure (scenario incomplete)"))

        for name in ["host-load.log", "host-memory.log"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: artifacts
                .appendingPathComponent("ios-ignored-signal-environment/\(name)").path))
        }

        let commandLogs = try FileManager.default.contentsOfDirectory(
            at: artifacts.appendingPathComponent("ios-ignored-signal-commands"), includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.contains("get_app_container") }
        XCTAssertEqual(commandLogs.count, 2)

        for url in commandLogs {
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertTrue(text.contains("Started:"))
            XCTAssertTrue(text.contains("Elapsed:"))
            XCTAssertTrue(text.contains("Result: timeout after"))
            XCTAssertTrue(text.contains("Termination: signal 9"))
            XCTAssertTrue(text.contains("simulator unavailable"))
        }
    }

    func testWaitForAppToStop_whenCollectorFails_shouldRetainAppTimeoutAndBeforeAfterEvidence() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier)
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])

        let defaultHandler = fixture.commands.handler
        fixture.commands.handler = { call in
            if call.isCommand("sudo") {
                return ProcessResult(tool: call.tool, arguments: call.arguments, terminationStatus: 15,
                                     terminationReason: .uncaughtSignal, stdout: "",
                                     stderr: "Collection time limit reached", timedOut: false, timeout: call.timeout)
            }
            return try defaultHandler(call)
        }

        // -- Act --
        let stopped = try fixture.runner.waitForAppToStop(timeout: 0)

        // -- Assert --
        XCTAssertFalse(stopped)
        XCTAssertTrue(process.isRunning)
        XCTAssertEqual(fixture.runner.launchCount, 1)
        let directory = try XCTUnwrap(fixture.runner.launchArtifacts)
        let capture = try String(contentsOf: directory.appendingPathComponent("stackshot-command.log"), encoding: .utf8)
        XCTAssertTrue(capture.contains("Phase: diagnostics"))
        XCTAssertTrue(capture.contains("Result: signal 15"))
        XCTAssertTrue(capture.contains("Termination: signal 15"))
        XCTAssertTrue(capture.contains("Collection time limit reached"))
        XCTAssertTrue(capture.contains("-timelimit 60"))

        for name in ["timeout.log", "process.log", "process-after-stackshot.log", "host-load.log", "host-memory.log"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path))
        }

        XCTAssertEqual(fixture.commands.calls.filter { $0.isCommand("sudo") }.count, 1)
        XCTAssertEqual(fixture.commands.calls.filter { $0.isCommand("ps") }.count, 2)
    }

    func testWaitForAppToStop_whenExitOccursDuringDiagnostics_shouldStillFailDeadline() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier)
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])

        let defaultHandler = fixture.commands.handler
        fixture.commands.handler = { call in
            if call.isCommand("sudo") {
                process.terminate()
                process.waitUntilExit()
            }
            return try defaultHandler(call)
        }

        // -- Act --
        let stopped = try fixture.runner.waitForAppToStop(timeout: 0)
        try fixture.runner.terminateApp()

        // -- Assert --
        XCTAssertFalse(stopped, "Diagnostics must not extend the scenario's acceptance deadline")
        XCTAssertNil(fixture.runner.appProcess)
        XCTAssertFalse(fixture.commands.calls.contains { $0.isCommand("xcrun", ["simctl", "terminate"]) })
        let directory = try XCTUnwrap(fixture.runner.launchArtifacts)
        let after = try String(contentsOf: directory.appendingPathComponent("process-after-stackshot.log"), encoding: .utf8)
        XCTAssertTrue(after.contains("Exit confirmed during diagnostics"))
    }

    func testRunScenarios_whenReportAssertionFails_shouldNotRetryTheScenario() throws {
        // -- Arrange --
        let process = try startProcess()
        stopProcess(process)
        let fixture = try IOSRunnerFixture(pid: process.processIdentifier, scenarios: [.nsException])
        defer { fixture.remove() }

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.runScenarios()) { error in
            XCTAssertTrue(error is ReportAssertionFailure)
        }
        XCTAssertEqual(fixture.runner.launchCount, 2, "Exactly one crash and one drain; never retry an SDK assertion")
        let failure = try String(contentsOf: fixture.runner.config.artifactsDir.appendingPathComponent("ios-ns-exception-failure.log"), encoding: .utf8)
        XCTAssertTrue(failure.contains("Phase: report validation"))
        XCTAssertTrue(failure.contains("App state: known stopped"))
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
