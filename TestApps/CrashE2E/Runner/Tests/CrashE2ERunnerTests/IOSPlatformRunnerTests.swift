@testable import CrashE2ERunner
import Foundation
import XCTest

final class IOSPlatformRunnerTests: XCTestCase {
    func testWaitForAppToStop_whenExitedJobRemainsLoaded_shouldReturnTrue() throws {
        // -- Arrange --
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        process.waitUntilExit()

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier)
        defer { fixture.remove() }

        let result = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])
        try fixture.runner.assertLaunchSucceeded(result, scenario: .nsExceptionRethrow, launchType: "drain")

        // -- Act --
        let stopped = try fixture.runner.waitForAppToStop(timeout: 0.05)

        // -- Assert --
        XCTAssertTrue(stopped)
        XCTAssertFalse(fixture.commands.calls.contains { $0.arguments.contains("launchctl") },
                       "Loaded jobs must not be used for liveness")
    }

    func testWaitForAppToStop_whenLaunchctlFailsAndProcessIsAlive_shouldFailAndSaveDiagnostics() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier, launchctlStatus: 1)
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])

        // -- Act --
        let stopped = try fixture.runner.waitForAppToStop(timeout: 0.01)

        // -- Assert --
        XCTAssertFalse(stopped, "An empty, failed launchctl response must not masquerade as app termination")
        XCTAssertTrue(process.isRunning)

        let directory = try XCTUnwrap(fixture.runner.launchArtifacts)
        let launch = try String(contentsOf: directory.appendingPathComponent("launch.log"), encoding: .utf8)
        XCTAssertTrue(launch.contains("--stdout="))
        XCTAssertTrue(launch.contains("--stderr="))
        XCTAssertTrue(launch.contains("\(process.processIdentifier)"))
        for name in ["timeout.log", "process.log", "stackshot.spindump", "stackshot-command.log",
                     "process-after-stackshot.log", "host-load.log", "host-memory.log", "launchctl.log"] {
            XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path), name)
        }

        let launchctl = try String(contentsOf: directory.appendingPathComponent("launchctl.log"), encoding: .utf8)
        XCTAssertTrue(launchctl.contains("status 1"))
        XCTAssertEqual(fixture.commands.calls.map(\.tool), ["xcrun", "ps", "sudo", "ps", "uptime", "vm_stat", "xcrun"])
        XCTAssertEqual(fixture.commands.calls.map(\.timeout), [30, 5, nil, 5, 5, 5, 5])
        XCTAssertTrue(fixture.commands.calls.allSatisfy { $0.captureOutput && $0.allowFailure })

        let launchCall = try XCTUnwrap(fixture.commands.calls.first)
        XCTAssertEqual(launchCall.arguments, [
            "simctl", "launch", "--stdout=\(directory.appendingPathComponent("stdout.log").path)",
            "--stderr=\(directory.appendingPathComponent("stderr.log").path)", fixture.runner.deviceID,
            Reporter.ksCrash.iOSBundleID, "--io.sentry.disable-http-transport", "--scenario", "drain"
        ])
    }

    func testLaunchApp_whenPIDIsMalformed_shouldThrowAndPreserveLaunchOutput() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0)
        defer { fixture.remove() }

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.launchApp(arguments: ["--scenario", "drain"]))
        XCTAssertThrowsError(try fixture.runner.waitForAppToStop(timeout: 0))

        let directory = try XCTUnwrap(fixture.runner.launchArtifacts)
        let launch = try String(contentsOf: directory.appendingPathComponent("launch.log"), encoding: .utf8)
        XCTAssertTrue(launch.contains("\(Reporter.ksCrash.iOSBundleID): 0"))
    }

    func testLaunchApp_whenSimctlFails_shouldNotObservePID() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: ProcessInfo.processInfo.processIdentifier, launchStatus: 1)
        defer { fixture.remove() }

        // -- Act --
        let result = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])

        // -- Assert --
        XCTAssertThrowsError(try fixture.runner.assertLaunchSucceeded(result, scenario: .nsException, launchType: "drain"))
        XCTAssertThrowsError(try fixture.runner.waitForAppToStop(timeout: 0))
        XCTAssertNil(fixture.runner.appProcess)
    }

    func testTerminateApp_whenProcessIsAlive_shouldWaitForExit() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier, onTerminate: { process.terminate() })
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])
        let observer = try XCTUnwrap(fixture.runner.appProcess)

        // -- Act --
        try fixture.runner.terminateApp()

        // -- Assert --
        XCTAssertTrue(try observer.wait(timeout: 0))
        XCTAssertNil(fixture.runner.appProcess)
    }

    func testTerminateApp_whenSimctlFails_shouldThrow() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0, terminateStatus: 1)
        defer { fixture.remove() }

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.terminateApp())
    }

    func testTerminateApp_whenNothingIsRunning_shouldSucceed() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0, terminateStatus: 3)
        defer { fixture.remove() }

        // -- Act & Assert --
        XCTAssertNoThrow(try fixture.runner.terminateApp())
    }

    func testLaunchApp_whenPreviousProcessIsAlive_shouldRefuseAnotherLaunch() throws {
        // -- Arrange --
        let process = try startProcess()
        defer { stopProcess(process) }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier)
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.launchApp(arguments: ["--scenario", "drain"]))
        XCTAssertEqual(fixture.runner.appProcess?.processIdentifier, process.processIdentifier)
        XCTAssertEqual(fixture.runner.launchCount, 1)
    }

    func testPreserveFailureCache_whenOriginalCacheIsCleared_shouldKeepReportsAndEnvelopes() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0)
        defer { fixture.remove() }

        _ = try fixture.runner.dataContainer()
        let cache = fixture.directory.appendingPathComponent("Library/Caches")
        let names = ["io.sentry", "KSCrash", "SentryCrash"]
        for name in names {
            let source = cache.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
            try Data(name.utf8).write(to: source.appendingPathComponent("evidence"))
        }

        // -- Act --
        fixture.runner.preserveFailureCache(scenario: .nsExceptionRethrow)
        try FileManager.default.removeItem(at: cache)

        // -- Assert --
        let snapshot = fixture.runner.config.artifactsDir.appendingPathComponent("ios-ns-exception-rethrow-failed-cache")
        for name in names {
            let evidence = try Data(contentsOf: snapshot.appendingPathComponent("\(name)/evidence"))
            XCTAssertEqual(evidence, Data(name.utf8))
        }
    }

    func testRunScenarios_whenKnownFailureHasMalformedPID_shouldFailAndCleanUp() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0, reporter: .sentryCrash, scenarios: [.objcObject])
        defer { fixture.remove() }

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.runScenarios()) { error in
            XCTAssertTrue(String(describing: error).contains("Could not parse"))
        }

        let calls = fixture.commands.calls
        let launchIndex = try XCTUnwrap(calls.firstIndex { $0.isCommand("xcrun", ["simctl", "launch"]) })
        XCTAssertTrue(calls.dropFirst(launchIndex + 1).contains { $0.isCommand("xcrun", ["simctl", "terminate"]) })
    }

    func testRunScenarios_whenKnownFailureHasLaunchFailure_shouldFailAndCleanUp() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0, launchStatus: 1, reporter: .sentryCrash, scenarios: [.objcObject])
        defer { fixture.remove() }

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.runScenarios()) { error in
            XCTAssertTrue(String(describing: error).contains("simctl launch failed"))
        }

        let calls = fixture.commands.calls
        let launchIndex = try XCTUnwrap(calls.firstIndex { $0.isCommand("xcrun", ["simctl", "launch"]) })
        XCTAssertTrue(calls.dropFirst(launchIndex + 1).contains { $0.isCommand("xcrun", ["simctl", "terminate"]) })
    }

    func testRunScenarios_whenKnownReportIsMissing_shouldCleanUpAndPreserveCache() throws {
        // -- Arrange --
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        process.waitUntilExit()

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier, reporter: .sentryCrash, scenarios: [.objcObject], onLaunch: { directory in
            let cache = directory.appendingPathComponent("Library/Caches/io.sentry")
            try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
            try Data("evidence\n".utf8).write(to: cache.appendingPathComponent("evidence"))
        })
        defer { fixture.remove() }

        // -- Act --
        try fixture.runner.runScenarios()

        // -- Assert --
        XCTAssertEqual(fixture.runner.launchCount, 2, "Both crash and drain launches must complete before classifying a report failure")
        XCTAssertNil(fixture.runner.appProcess)

        let snapshot = fixture.runner.config.artifactsDir.appendingPathComponent("ios-objc-object-failed-cache/io.sentry/evidence")
        XCTAssertEqual(try String(contentsOf: snapshot, encoding: .utf8), "evidence\n")
    }

    func testRunScenarios_whenCleanupFailsWithKeepGoing_shouldAbortBeforeNextScenario() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0, cleanupStatus: 1, reporter: .sentryCrash,
                                            scenarios: [.objcObject, .signal], keepGoing: true)
        defer { fixture.remove() }

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.runScenarios()) { error in
            XCTAssertTrue(String(describing: error).contains("Could not stop iOS app after failure"))
        }
        XCTAssertEqual(fixture.runner.launchCount, 1)
        XCTAssertEqual(fixture.runner.scenarioName, Scenario.objcObject.rawValue)
    }

    func testRunScenarios_whenInfrastructureFailsWithKeepGoing_shouldCleanUpAndReportFailures() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0, reporter: .sentryCrash,
                                            scenarios: [.objcObject, .objcObjectAfterCaughtCPP], keepGoing: true)
        defer { fixture.remove() }

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.runScenarios()) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("iOS/objc-object:"))
            XCTAssertTrue(message.contains("iOS/objc-object-after-caught-cpp:"))
        }
        XCTAssertEqual(fixture.runner.launchCount, 2)

        let terminations = fixture.commands.calls.filter { $0.isCommand("xcrun", ["simctl", "terminate"]) }
        XCTAssertEqual(terminations.count, 3, "Initial isolation and two failed-launch cleanups; stopped scenario starts need no command")
    }

    func testLaunchApp_whenCommandTimesOut_shouldNotObservePID() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0)
        defer { fixture.remove() }

        fixture.commands.handler = { call in
            XCTAssertTrue(call.isCommand("xcrun", ["simctl", "launch"]))
            return call.result(stdout: "\(Reporter.ksCrash.iOSBundleID): \(ProcessInfo.processInfo.processIdentifier)", timedOut: true)
        }

        // -- Act --
        let result = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])

        // -- Assert --
        XCTAssertThrowsError(try fixture.runner.assertLaunchSucceeded(result, scenario: .nsException, launchType: "drain")) { error in
            XCTAssertTrue(String(describing: error).contains("simctl launch timed out"))
        }
        XCTAssertNil(fixture.runner.appProcess)
        XCTAssertEqual(fixture.commands.calls.count, 1)
    }

    func testRunScenarios_whenCommandThrows_shouldPreserveErrorAndCleanUp() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0, reporter: .sentryCrash, scenarios: [.objcObject])
        defer { fixture.remove() }

        let failure = CocoaError(.fileReadNoPermission)
        let defaultHandler = fixture.commands.handler
        fixture.commands.handler = { call in
            if call.isCommand("xcrun", ["simctl", "launch"]) { throw failure }
            return try defaultHandler(call)
        }

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.runScenarios()) { error in
            XCTAssertEqual(error as? CocoaError, failure)
        }

        let calls = fixture.commands.calls
        let launchIndex = try XCTUnwrap(calls.firstIndex { $0.isCommand("xcrun", ["simctl", "launch"]) })
        XCTAssertTrue(calls.dropFirst(launchIndex + 1).contains { $0.isCommand("xcrun", ["simctl", "terminate"]) })
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

extension IOSPlatformRunnerTests {
    func testRunScenarios_whenInstallingApp_shouldStopUninstallAndInstallInOrder() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0, launchStatus: 1, scenarios: [.signal])
        defer { fixture.remove() }
        let runner = fixture.runner
        let app = runner.config.derivedDataPath.appendingPathComponent("Build/Products/Debug-iphonesimulator/\(runner.config.reporter.iOSAppName)")

        // -- Act --
        XCTAssertThrowsError(try runner.runScenarios()) { error in
            XCTAssertTrue(String(describing: error).contains("simctl launch failed"))
        }

        // -- Assert --
        let installationCalls = Array(fixture.commands.calls.prefix(3))
        XCTAssertEqual(installationCalls.map(\.tool), ["xcrun", "xcrun", "xcrun"])
        XCTAssertEqual(installationCalls.map(\.arguments), [
            ["simctl", "terminate", runner.deviceID, runner.bundleID],
            ["simctl", "uninstall", runner.deviceID, runner.bundleID],
            ["simctl", "install", runner.deviceID, app.path]
        ])
        XCTAssertEqual(installationCalls.map(\.allowFailure), [true, true, false])
        XCTAssertEqual(installationCalls.map(\.captureOutput), [true, true, false])
    }

    func testRunScenarios_whenRetryLaunchFails_shouldUseOnlySharedTerminationAndCleanup() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0, launchStatus: 1, scenarios: [.ksCrashPerReportRetry])
        defer { fixture.remove() }

        // -- Act --
        XCTAssertThrowsError(try fixture.runner.runScenarios()) { error in
            XCTAssertTrue(String(describing: error).contains("simctl launch failed"))
        }

        // -- Assert --
        XCTAssertEqual(fixture.commands.calls.map { Array($0.arguments.prefix(2)) }, [
            ["simctl", "terminate"], ["simctl", "uninstall"], ["simctl", "install"],
            ["simctl", "get_app_container"], ["simctl", "launch"], ["simctl", "terminate"]
        ])

        let terminations = fixture.commands.calls.filter { $0.isCommand("xcrun", ["simctl", "terminate"]) }
        XCTAssertTrue(terminations.allSatisfy { $0.timeout == 10 && $0.captureOutput && $0.allowFailure })
    }

    func testPrepareSimulator_whenShutdown_shouldRequestBootThenWaitForReadiness() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0)
        defer { fixture.remove() }

        fixture.commands.handler = { call in
            if call.isCommand("xcrun", ["simctl", "list"]) {
                return call.result(stdout: """
                {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
                    {"name": "iPhone 17 Pro", "udid": "test-device", "state": "Shutdown", "isAvailable": true}
                ]}}
                """)
            }
            if call.isCommand("xcrun", ["simctl", "boot"]) {
                // A concurrent boot can make the request fail; readiness is decided by bootstatus.
                XCTAssertTrue(call.allowFailure)
                return call.result(status: 1)
            }
            XCTAssertEqual(call.arguments, ["simctl", "bootstatus", "test-device", "-b"])
            XCTAssertFalse(call.allowFailure)
            XCTAssertEqual(call.timeout, 180)
            return call.result()
        }

        // -- Act --
        try fixture.runner.prepareSimulator()

        // -- Assert --
        XCTAssertEqual(fixture.runner.deviceID, "test-device")
        XCTAssertEqual(fixture.commands.calls.map(\.arguments), [
            ["simctl", "list", "devices", "available", "-j"],
            ["simctl", "boot", "test-device"], ["simctl", "bootstatus", "test-device", "-b"]
        ])
    }
}
