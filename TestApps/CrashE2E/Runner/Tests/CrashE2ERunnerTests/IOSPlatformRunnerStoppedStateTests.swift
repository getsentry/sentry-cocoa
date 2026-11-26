@testable import CrashE2ERunner
import Foundation
import XCTest

final class IOSPlatformRunnerStoppedStateTests: XCTestCase {
    func testWaitForAppToStop_whenSimulatorConfirmedStopWithoutPID_shouldReturnTrue() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0)
        defer { fixture.remove() }
        try fixture.runner.terminateApp()

        let commandCount = fixture.commands.calls.count

        // -- Act & Assert --
        XCTAssertTrue(try fixture.runner.waitForAppToStop(timeout: 0))
        XCTAssertEqual(fixture.commands.calls.count, commandCount)
    }

    func testWaitForAppToStop_whenSimulatorReportedNoSuchProcess_shouldReturnTrue() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0, terminateStatus: 3)
        defer { fixture.remove() }
        try fixture.runner.terminateApp()

        // -- Act & Assert --
        XCTAssertTrue(try fixture.runner.waitForAppToStop(timeout: 0))
        XCTAssertEqual(fixture.commands.calls.count, 1)
    }

    func testWaitForAppToStop_whenStopHasPID_shouldReturnTrue() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0)
        defer { fixture.remove() }
        fixture.runner.confirmAppStopped(pid: 123)

        // -- Act & Assert --
        XCTAssertTrue(try fixture.runner.waitForAppToStop(timeout: 0))
        XCTAssertEqual(fixture.commands.calls.count, 0)
    }

    func testWaitForAppToStop_whenStateIsUnknown_shouldThrow() throws {
        // -- Arrange --
        let fixture = try IOSRunnerFixture(pid: 0)
        defer { fixture.remove() }

        // -- Act & Assert --
        XCTAssertThrowsError(try fixture.runner.waitForAppToStop(timeout: 0))
        XCTAssertEqual(fixture.commands.calls.count, 0)
    }

    func testLaunchApp_whenLaunchFails_shouldInvalidateEitherStoppedState() throws {
        for pid in [nil, Int32(123)] {
            // -- Arrange --
            let fixture = try IOSRunnerFixture(pid: 0, launchStatus: 1)
            defer { fixture.remove() }
            fixture.runner.confirmAppStopped(pid: pid)

            // -- Act --
            let result = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])

            // -- Assert --
            XCTAssertFalse(result.succeeded)
            XCTAssertThrowsError(try fixture.runner.waitForAppToStop(timeout: 0))
        }
    }

    func testLaunchApp_whenLaunchSucceeds_shouldInvalidateEitherStoppedState() throws {
        // -- Arrange --
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["60"]

        try process.run()
        defer {
            process.terminate()
            process.waitUntilExit()
        }

        for pid in [nil, Int32(123)] {
            let fixture = try IOSRunnerFixture(pid: process.processIdentifier)
            defer { fixture.remove() }
            fixture.runner.confirmAppStopped(pid: pid)

            // -- Act --
            _ = try fixture.runner.launchApp(arguments: ["--scenario", "drain"])

            // -- Assert --
            XCTAssertEqual(fixture.runner.appProcess?.processIdentifier, process.processIdentifier)
            XCTAssertFalse(try fixture.runner.waitForAppToStop(timeout: 0))
        }
    }
}
