@testable import CrashE2ERunner
import Foundation
import XCTest

final class IOSPlatformRunnerSigtermTests: XCTestCase {
    func testRunScenarios_whenSigtermReadinessAndCleanupFail_shouldPreserveBothErrorsAndAbort() throws {
        // -- Arrange --
        // Keep the process alive and omit the ready marker. Exercising the real readiness
        // timeout avoids a test-only hook, and a live process keeps this independent of
        // the cleanup behavior for processes whose exit is already confirmed.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sleep")
        process.arguments = ["60"]
        try process.run()
        defer {
            if process.isRunning { process.terminate() }
            process.waitUntilExit()
        }

        let fixture = try IOSRunnerFixture(pid: process.processIdentifier, scenarios: [.sigterm, .signal], keepGoing: true)
        defer { fixture.remove() }

        let defaultHandler = fixture.commands.handler
        var launched = false
        fixture.commands.handler = { call in
            if launched && call.isCommand("xcrun", ["simctl", "terminate"]) {
                throw CrashE2EFailure(message: "simulated simulator failure during cleanup")
            }
            let result = try defaultHandler(call)
            if call.isCommand("xcrun", ["simctl", "launch"]) { launched = true }
            return result
        }

        // -- Act --
        XCTAssertThrowsError(try fixture.runner.runScenarios()) { error in
            let message = String(describing: error)
            XCTAssertTrue(message.contains("ios/sigterm app did not write the ready marker"))
            XCTAssertTrue(message.contains("Could not stop iOS app after failure: simulated simulator failure during cleanup"))
        }

        // -- Assert --
        XCTAssertTrue(process.isRunning)
        XCTAssertEqual(fixture.runner.launchCount, 1, "Cleanup failure must override keep-going")
        XCTAssertEqual(fixture.runner.scenarioName, Scenario.sigterm.rawValue)

        let calls = fixture.commands.calls
        let launchIndex = try XCTUnwrap(calls.firstIndex { $0.isCommand("xcrun", ["simctl", "launch"]) })
        let cleanupCalls = calls.dropFirst(launchIndex + 1).filter { $0.isCommand("xcrun", ["simctl", "terminate"]) }
        
        XCTAssertEqual(cleanupCalls.count, 1, "The scenario error should trigger one termination attempt in runScenarioWithCleanup")
        XCTAssertFalse(calls.dropFirst(launchIndex + 1).contains { $0.isCommand("xcrun", ["simctl", "get_app_container"]) },
                       "Do not snapshot a cache still in use by a live process")
    }
}
