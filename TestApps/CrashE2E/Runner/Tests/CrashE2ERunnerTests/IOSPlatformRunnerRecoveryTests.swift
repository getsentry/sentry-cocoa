@testable import CrashE2ERunner
import Foundation
import XCTest

final class IOSPlatformRunnerRecoveryTests: XCTestCase {
    func testTerminateApp_whenAlreadyStopped_shouldRetainConfirmationWithoutAnotherCommand() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: try exitedPID())
        defer { fixture.remove() }

        _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])

        XCTAssertTrue(try fixture.runner.waitForAppToStop(timeout: 5))

        try fixture.runner.terminateApp()
        let count = fixture.commands.calls.count
        fixture.commands.handler = { _ in throw CrashE2EFailure(message: "simulator unavailable") }

        // -- Act & Assert --
        XCTAssertNoThrow(try fixture.runner.terminateApp())
        XCTAssertEqual(fixture.commands.calls.count, count)
    }

    func testTerminateApp_whenUnobservedRequestTimesOutOnce_shouldRetryBeforeFailing() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0)
        defer { fixture.remove() }

        var attempts = 0
        fixture.commands.handler = { call in
            XCTAssertTrue(call.isCommand("xcrun", ["simctl", "terminate"]))
            attempts += 1
            if attempts == 1 { return call.result(timedOut: true) }

            return call.result(status: 3, stderr: "domain=NSPOSIXErrorDomain, code=3")
        }

        // -- Act & Assert --
        XCTAssertNoThrow(try fixture.runner.terminateApp())
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(fixture.commands.calls.map(\.timeout), [10, 30])
    }

    func testDataContainer_whenLookupTimesOutOnce_shouldRetryWithoutLaunchingOrTerminating() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0)
        defer { fixture.remove() }

        var attempts = 0
        let containerPath = fixture.directory.path
        fixture.commands.handler = { call in
            XCTAssertTrue(call.isCommand("xcrun", ["simctl", "get_app_container"]))
            attempts += 1

            return attempts == 1 ? call.result(timedOut: true) : call.result(stdout: containerPath)
        }

        // -- Act --
        let container = try fixture.runner.dataContainer()

        // -- Assert --
        XCTAssertEqual(container.path, fixture.directory.path)
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(fixture.runner.launchCount, 0)
    }

    func testRunScenarios_whenContainerLookupTimesOutAfterConfirmedExit_shouldRecoverAndFinish() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: try exitedPID(), scenarios: [.ignoredSignal, .closedSignal], keepGoing: true)
        defer { fixture.remove() }

        let defaultHandler = fixture.commands.handler
        var lookups = 0
        var launched = false
        fixture.commands.handler = { call in
            if call.isCommand("xcrun", ["simctl", "get_app_container"]) {
                lookups += 1
                if lookups == 2 { return call.result(timedOut: true) }
            }

            if call.isCommand("xcrun", ["simctl", "terminate"]), launched {
                return call.result(timedOut: true)
            }

            if call.isCommand("xcrun", ["simctl", "launch"]) { launched = true }

            return try defaultHandler(call)
        }

        // -- Act & Assert --
        XCTAssertNoThrow(try fixture.runner.runScenarios())
        XCTAssertEqual(lookups, 3)
        XCTAssertEqual(fixture.runner.launchCount, 4, "Both scenarios must execute crash and drain launches")
        XCTAssertEqual(fixture.commands.calls.filter { $0.isCommand("xcrun", ["simctl", "terminate"]) }.count, 1)
    }

    func testRunScenarios_whenLookupRetriesAreExhausted_shouldReportIncompleteScenarioAndContinueSafely() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: try exitedPID(), scenarios: [.ignoredSignal, .closedSignal, .closedNSException], keepGoing: true)
        defer { fixture.remove() }

        let defaultHandler = fixture.commands.handler
        var lookups = 0
        var launched = false
        fixture.commands.handler = { call in
            if call.isCommand("xcrun", ["simctl", "get_app_container"]) {
                lookups += 1
                if lookups == 2 || lookups == 3 { return call.result(timedOut: true) }
            }

            if call.isCommand("xcrun", ["simctl", "terminate"]), launched {
                return call.result(timedOut: true)
            }

            if call.isCommand("xcrun", ["simctl", "launch"]) { launched = true }

            return try defaultHandler(call)
        }

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.runScenarios()) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("infrastructure"))
            XCTAssertTrue(message.contains("closed-signal"))
            XCTAssertFalse(message.contains("Could not stop iOS app"))
        }
        XCTAssertEqual(fixture.runner.launchCount, 4, "The incomplete scenario must not be counted as an executed test")
        XCTAssertEqual(fixture.runner.scenarioName, Scenario.closedNSException.rawValue)
    }

    func testLaunchApp_whenLaunchTimesOutAfterStoppedState_shouldRequireCleanupWithoutRetryingLaunch() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0)
        defer { fixture.remove() }

        try fixture.runner.terminateApp()
        let defaultHandler = fixture.commands.handler
        fixture.commands.handler = { call in
            if call.isCommand("xcrun", ["simctl", "launch"]) { return call.result(timedOut: true) }
            return try defaultHandler(call)
        }

        // -- Act --
        let result = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])
        try fixture.runner.terminateApp()

        // -- Assert --
        XCTAssertTrue(result.timedOut)
        XCTAssertEqual(fixture.commands.calls.filter { $0.isCommand("xcrun", ["simctl", "launch"]) }.count, 1)
        XCTAssertEqual(fixture.commands.calls.filter { $0.isCommand("xcrun", ["simctl", "terminate"]) }.count, 2)
    }

    func testDataContainer_whenCommandReturnsPermanentError_shouldNotRetry() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0)
        defer { fixture.remove() }

        fixture.commands.handler = { call in call.result(status: 2, stderr: "no such app") }

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.dataContainer())
        XCTAssertEqual(fixture.commands.calls.count, 1)
    }

    func testTerminateApp_whenRequestsKeepTimingOut_shouldExhaustBoundedRetriesWithoutClaimingExit() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0)
        defer { fixture.remove() }

        fixture.commands.handler = { call in call.result(timedOut: true) }

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.terminateApp())
        XCTAssertEqual(fixture.commands.calls.map(\.timeout), [10, 30])
        XCTAssertThrowsError(try fixture.runner.waitForAppToStop(timeout: 0), "A control-command timeout is not an observed app exit")
    }

    func testPrepareSimulator_whenDeviceChanges_shouldInvalidateStopConfirmation() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0)
        defer { fixture.remove() }

        let defaultHandler = fixture.commands.handler
        var device = "first-device"
        fixture.commands.handler = { call in
            if call.isCommand("xcrun", ["simctl", "list"]) {
                return call.result(stdout: """
                {"devices": {"com.apple.CoreSimulator.SimRuntime.iOS-26-5": [
                    {"name": "iPhone 17 Pro", "udid": "\(device)", "state": "Booted", "isAvailable": true}
                ]}}
                """)
            }

            return try defaultHandler(call)
        }
        try fixture.runner.prepareSimulator()
        try fixture.runner.terminateApp()

        // -- Act --
        device = "second-device"
        try fixture.runner.prepareSimulator()
        try fixture.runner.terminateApp()

        // -- Assert --
        let calls = fixture.commands.calls.filter { $0.isCommand("xcrun", ["simctl", "terminate"]) }
        XCTAssertEqual(calls.map(\.arguments), [
            ["simctl", "terminate", "first-device", fixture.runner.bundleID],
            ["simctl", "terminate", "second-device", fixture.runner.bundleID]
        ])
    }

    private func exitedPID() throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        process.waitUntilExit()
        return process.processIdentifier
    }
}
