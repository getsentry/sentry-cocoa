@testable import CrashE2ERunner
import Foundation
import XCTest

final class IOSPlatformRunnerCleanupTests: XCTestCase {
    func testTerminateApp_whenExitIsConfirmed_shouldNotRequireSimctl() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier, cleanupStatus: 1)
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])
        let observer = try XCTUnwrap(fixture.runner.appProcess)
        stopProcess(process)
        XCTAssertTrue(try observer.wait(timeout: 5))

        // -- Act --
        XCTAssertNoThrow(try fixture.runner.terminateApp())

        // -- Assert --
        XCTAssertNil(fixture.runner.appProcess)
        XCTAssertFalse(fixture.commands.calls.contains { $0.isCommand("xcrun", ["simctl", "terminate"]) })
    }

    func testTerminateApp_whenProcessExitsDuringFailedCommand_shouldAcceptExit() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier)
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])
        let observer = try XCTUnwrap(fixture.runner.appProcess)
        fixture.commands.handler = { call in
            XCTAssertTrue(call.isCommand("xcrun", ["simctl", "terminate"]))
            process.terminate()
            process.waitUntilExit()
            return call.result(status: 1, stderr: "simulated simulator failure")
        }

        // -- Act --
        XCTAssertNoThrow(try fixture.runner.terminateApp())

        // -- Assert --
        XCTAssertTrue(try observer.wait(timeout: 0))
        XCTAssertNil(fixture.runner.appProcess)
    }

    func testTerminateApp_whenProcessExitsDuringTimedOutCommand_shouldAcceptExit() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier)
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])
        let observer = try XCTUnwrap(fixture.runner.appProcess)
        fixture.commands.handler = { call in
            XCTAssertTrue(call.isCommand("xcrun", ["simctl", "terminate"]))
            process.terminate()
            process.waitUntilExit()
            return call.result(stderr: "simulated simulator timeout", timedOut: true)
        }

        // -- Act --
        XCTAssertNoThrow(try fixture.runner.terminateApp())

        // -- Assert --
        XCTAssertTrue(try observer.wait(timeout: 0))
        XCTAssertNil(fixture.runner.appProcess)
    }

    func testTerminateApp_whenProcessExitsDuringThrowingCommand_shouldAcceptExit() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier)
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])
        let observer = try XCTUnwrap(fixture.runner.appProcess)
        fixture.commands.handler = { call in
            XCTAssertTrue(call.isCommand("xcrun", ["simctl", "terminate"]))
            process.terminate()
            process.waitUntilExit()
            throw CocoaError(.fileReadNoPermission)
        }

        // -- Act --
        XCTAssertNoThrow(try fixture.runner.terminateApp())

        // -- Assert --
        XCTAssertTrue(try observer.wait(timeout: 0))
        XCTAssertNil(fixture.runner.appProcess)
    }

    func testTerminateApp_whenUnobservedCommandTimesOut_shouldRejectNoSuchProcessResponse() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0)
        defer { fixture.remove() }

        fixture.commands.handler = { call in
            XCTAssertTrue(call.isCommand("xcrun", ["simctl", "terminate"]))
            return call.result(status: 3, stderr: "domain=NSPOSIXErrorDomain, code=3", timedOut: true)
        }

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.terminateApp()) { error in
            XCTAssertTrue(String(describing: error).contains("timeout after 30s"))
        }
    }

    func testTerminateApp_whenProcessSurvivesSuccessfulCommand_shouldFailAndRetainObserver() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier)
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])
        let observer = try XCTUnwrap(fixture.runner.appProcess)

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.terminateApp()) { error in
            XCTAssertTrue(String(describing: error).contains("survived cleanup"))
        }
        XCTAssertTrue(process.isRunning)
        XCTAssertTrue(fixture.runner.appProcess === observer)
    }

    func testRunScenarios_whenExitIsConfirmedWithKeepGoing_shouldPreserveCachesAndContinue() throws {
        // -- Arrange --
        let process = try startProcess()
        stopProcess(process)

        let scenarios: [Scenario] = [.nsException, .cppExceptionV1]

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier, scenarios: scenarios, keepGoing: true, onLaunch: { directory in
            let cache = directory.appendingPathComponent("Library/Caches/io.sentry")
            try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
            try Data("evidence".utf8).write(to: cache.appendingPathComponent("evidence"))
        })
        defer { fixture.remove() }

        let defaultHandler = fixture.commands.handler
        fixture.commands.handler = { [weak runner = fixture.runner] call in
            if call.isCommand("xcrun", ["simctl", "terminate"]), runner?.appProcess != nil {
                return call.result(status: 1, stderr: "simulated simulator failure after exit")
            }
            return try defaultHandler(call)
        }

        // -- Act --
        XCTAssertThrowsError(try fixture.runner.runScenarios()) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("iOS/ns-exception: Expected exactly one event envelope"))
            XCTAssertTrue(message.contains("iOS/cpp-exception-v1: Expected exactly one event envelope"))
            XCTAssertFalse(message.contains("Could not stop iOS app"))
        }

        // -- Assert --
        XCTAssertEqual(fixture.runner.launchCount, 4, "Both scenarios must reach their crash and drain launches")
        XCTAssertNil(fixture.runner.appProcess)

        for scenario in scenarios {
            let snapshot = fixture.runner.config.artifactsDir
                .appendingPathComponent("ios-\(scenario.rawValue)-failed-cache/io.sentry/evidence")
            XCTAssertEqual(try Data(contentsOf: snapshot), Data("evidence".utf8))
        }
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
