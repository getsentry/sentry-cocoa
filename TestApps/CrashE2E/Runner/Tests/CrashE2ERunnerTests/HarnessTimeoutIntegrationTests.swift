@testable import CrashE2ERunner
import Foundation
import XCTest

/// Opt-in live test: requires a built app, an iOS simulator and non-interactive spindump authorization.
final class HarnessTimeoutIntegrationTests: XCTestCase {
    func testRun_whenAppDeliberatelyWaits_shouldCaptureCleanUpAndKeepGoingWithoutHidingTimeout() throws {
        // -- Arrange --
        let environment = ProcessInfo.processInfo.environment
        guard environment["CRASH_E2E_HARNESS_TIMEOUT_TEST"] == "1" else {
            throw XCTSkip("Set CRASH_E2E_HARNESS_TIMEOUT_TEST=1 to run the live iOS harness test; see CrashE2E/README.md")
        }

        let derivedData = try XCTUnwrap(environment["CRASH_E2E_TEST_DERIVED_DATA"])
        let artifacts = absoluteURL(try XCTUnwrap(environment["CRASH_E2E_TEST_ARTIFACTS"]))
        let reporter = try XCTUnwrap(Reporter(caseInsensitive: environment["CRASH_E2E_TEST_REPORTER"] ?? "SentryCrash"))
        guard !FileManager.default.fileExists(atPath: artifacts.path) else {
            XCTFail("Use a fresh artifact directory: \(artifacts.path)")
            return
        }

        let runnerArtifacts = artifacts.appendingPathComponent("runner")
        let outputFile = artifacts.appendingPathComponent("runner-output.log")
        let executable = Bundle(for: Self.self).bundleURL.deletingLastPathComponent()
            .appendingPathComponent("CrashE2ERunner")
        var arguments = ["--platform", "ios", "--reporter", reporter.rawValue,
                         "--scenarios", "harness-timeout,signal", "--keep-going", "--keep-artifacts",
                         "--skip-build", "--derived-data-path", derivedData, "--artifacts-dir", runnerArtifacts.path]

        if let deviceID = environment["CRASH_E2E_TEST_IOS_DEVICE_ID"] {
            arguments += ["--ios-device-id", deviceID]
        }
        if let destination = environment["CRASH_E2E_TEST_IOS_DESTINATION"] {
            arguments += ["--ios-destination", destination]
        }

        print("Live harness test artifacts: \(artifacts.path)")

        // -- Act --
        // Do not replace command execution or shorten the normal 25-second app deadline.
        // The CI step/job is the outer bound, including the real privileged collector.
        let result = try ProcessRunner().run(executable.path, arguments, outputFile: outputFile, allowFailure: true)
        let output = try String(contentsOf: outputFile, encoding: .utf8)

        // -- Assert --
        XCTAssertEqual(result.terminationReason, .exit)
        XCTAssertEqual(result.terminationStatus, 1, output)
        XCTAssertTrue(output.hasSuffix("""
        ❌ Crash E2E completed with failures:
        - iOS/harness-timeout: iOS app did not terminate for scenario: harness-timeout

        """), output)

        let launch = runnerArtifacts.appendingPathComponent("ios-harness-timeout-launch-1")
        let launchLog = try read("launch.log", in: launch)
        let pid = try ProcessExitObserver.launchedProcessIdentifier(stdout: launchLog, bundleID: reporter.iOSBundleID)

        try assertTimeoutAndReadiness(in: launch, pid: pid)
        try assertCleanupAndProgress(in: runnerArtifacts, output: output, pid: pid)
        try assertSymbolicatedStacks(in: launch, pid: pid)
    }

    private func assertTimeoutAndReadiness(in launch: URL, pid: Int32) throws {
        let appLog = try read("stderr.log", in: launch)
        let sdkStarted = try XCTUnwrap(appLog.range(of: "CrashE2E - SDK started"))
        let ready = try XCTUnwrap(appLog.range(of:
            "CrashE2E - harness-timeout ready; waiting in crashE2EHarnessTimeoutWait (pid: \(pid))"))

        XCTAssertLessThan(sdkStarted.lowerBound, ready.lowerBound)
        XCTAssertFalse(appLog.contains("CrashE2E - idle"), "Unknown app scenarios must not count as readiness")

        let readyLine = try XCTUnwrap(appLog.split(separator: "\n").first { $0.contains(" ready-at: ") })
        let readyTime = try XCTUnwrap(readyLine.components(separatedBy: " ready-at: ").last.flatMap(Double.init))
        let launchLog = try read("launch.log", in: launch)
        let startedLine = try XCTUnwrap(launchLog.split(separator: "\n").first { $0.hasPrefix("Started: ") })
        let started = try XCTUnwrap(ISO8601DateFormatter().date(from: String(startedLine.dropFirst("Started: ".count))))
        let elapsedLine = try XCTUnwrap(launchLog.split(separator: "\n").first { $0.hasPrefix("Elapsed: ") })
        let elapsed = try XCTUnwrap(Double(elapsedLine.dropFirst("Elapsed: ".count).dropLast()))

        // The launch timestamp has whole-second precision, so this is a conservative lower
        // bound on the exit deadline. Readiness reached only during diagnostics is insufficient.
        XCTAssertLessThan(readyTime, started.timeIntervalSince1970 + elapsed + 25,
                          "The app must reach its intentional wait before the exit deadline")
        XCTAssertEqual(try read("timeout.log", in: launch), """
        Scenario: ios/harness-timeout
        Phase: waiting for app exit
        App state: observing PID \(pid) (exit not yet confirmed)
        Failure: PID \(pid) did not exit within 25.0s
        """)
    }

    private func assertCleanupAndProgress(in artifacts: URL, output: String, pid: Int32) throws {
        XCTAssertEqual(try read("ios-harness-timeout-failure.log", in: artifacts), """
        Scenario: ios/harness-timeout
        Phase: waiting for app exit
        App state: observing PID \(pid) (exit not yet confirmed)
        Error: iOS app did not terminate for scenario: harness-timeout
        """)

        // This state with a last PID is logged only after the real process observer confirms exit,
        // not merely when simctl returns success. It must precede the next scenario.
        let stopped = try XCTUnwrap(output.range(of:
            "[ios/harness-timeout, cleanup] App state: known stopped (last PID \(pid))"))
        let nextScenario = try XCTUnwrap(output.range(of: "iOS scenario: signal"))
        let passed = try XCTUnwrap(output.range(of: "✅ ios/signal assertions passed."))

        XCTAssertLessThan(stopped.lowerBound, nextScenario.lowerBound)
        XCTAssertLessThan(nextScenario.lowerBound, passed.lowerBound)
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifacts.appendingPathComponent("ios-signal-event.json").path))

        let names = try FileManager.default.contentsOfDirectory(atPath: artifacts.path)
        XCTAssertEqual(names.filter { $0.contains("-launch-") }.sorted(), [
            "ios-harness-timeout-launch-1", "ios-signal-launch-2", "ios-signal-launch-3"
        ], "No timeout scenario retries or drain; the following signal must crash and drain")
        XCTAssertEqual(names.filter { $0.hasSuffix("-failure.log") }, ["ios-harness-timeout-failure.log"])

        let signalLaunch = artifacts.appendingPathComponent("ios-signal-launch-2")
        let signalDrain = artifacts.appendingPathComponent("ios-signal-launch-3")
        XCTAssertTrue(try read("stderr.log", in: signalLaunch).contains("CrashE2E - will trigger scenario: signal"))
        XCTAssertTrue(try read("stderr.log", in: signalDrain).contains("CrashE2E - drain previous crash"))
    }

    private func assertSymbolicatedStacks(in launch: URL, pid: Int32) throws {
        if FileManager.default.fileExists(atPath: launch.appendingPathComponent("stackshot-unavailable.log").path) {
            XCTFail("Collector failure/authorization denial is not a passing timeout-path test: \(try read("stackshot-unavailable.log", in: launch))")
            return
        }
        let command = try read("stackshot-command.log", in: launch)

        XCTAssertTrue(command.contains("sudo -n /usr/sbin/spindump \(pid) 2 10 -onlyTarget"))
        XCTAssertTrue(command.contains("Result: status 0\nTermination: status 0"), command)

        // spindump saves binary data alongside its readable report. Inspect a symbolicated stack
        // line, not merely a symbol string that might occur in the binary data or app logs.
        let data = try Data(contentsOf: launch.appendingPathComponent("stackshot.spindump"))
        XCTAssertFalse(data.isEmpty)

        let report = String(decoding: data, as: UTF8.self)
        let frame = #"(?m)^\s+\d+\s+[^\n]*CrashE2ERuntime\.crashE2EHarnessTimeoutWait\(\)[^\n]*\[0x[0-9a-fA-F]+\]"#
        XCTAssertNotNil(report.range(of: frame, options: .regularExpression),
                        "Missing symbolicated app waiting frame in \(launch.path)/stackshot.spindump")
    }

    private func read(_ name: String, in directory: URL) throws -> String {
        try String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
    }
}
