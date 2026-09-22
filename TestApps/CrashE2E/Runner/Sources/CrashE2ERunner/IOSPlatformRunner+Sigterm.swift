import Foundation

extension IOSPlatformRunner {
    func runSigtermScenario(container: URL) throws {
        let cacheRoot = container.appendingPathComponent("Library/Caches", isDirectory: true)
        let readyMarker = cacheRoot.appendingPathComponent(SigtermScenarioConstants.readyMarkerFileName)
        // The container is shared across scenarios, so drop stale markers a previous drain wrote.
        try fileManager.removeItemIfExists(at: readyMarker)
        try fileManager.removeItemIfExists(
            at: cacheRoot.appendingPathComponent(SigtermScenarioConstants.lastRunMarkerFileName)
        )
        try terminateApp()

        let launchResult = try launchApp(arguments: ["--scenario", Scenario.sigterm.rawValue])
        try assertLaunchSucceeded(launchResult, scenario: .sigterm, launchType: "sigterm")
        let pid = try launchedProcessIdentifier(from: launchResult)

        // Simulator apps run as host processes, so the runner can signal the pid directly.
        do {
            try SigtermScenarioAsserter.waitForReadyMarker(at: readyMarker, platform: "ios")
            try SigtermScenarioAsserter.sendSigterm(to: pid, platform: "ios")
        } catch {
            // Otherwise the app aborts on its own timer later and leaves a report behind.
            try terminateApp()
            throw error
        }
        guard try waitForAppToStop(timeout: SigtermScenarioConstants.terminationTimeout) else {
            try fail("iOS app did not terminate after SIGTERM")
        }

        try SigtermScenarioAsserter.assertNoStoredCrashReports(cacheRoot: cacheRoot, platform: "ios")
        try drainPreviousCrash(for: .sigterm)
        try ScenarioEventAsserter.assertScenarioEvent(
            .sigterm,
            cacheRoot: cacheRoot,
            platform: "ios",
            artifactsDir: config.artifactsDir
        )
        try SigtermScenarioAsserter.assertLastRunNotCrashed(cacheRoot: cacheRoot, platform: "ios")
    }

    private func terminateApp() throws {
        try processRunner.run("xcrun", ["simctl", "terminate", deviceID, bundleID],
                              captureOutput: true, allowFailure: true)
    }

    /// `simctl launch` prints `<bundle id>: <pid>` on success.
    private func launchedProcessIdentifier(from result: ProcessResult) throws -> Int32 {
        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pidToken = output.split(whereSeparator: { $0 == ":" || $0 == " " }).last,
              let pid = Int32(pidToken.trimmingCharacters(in: .whitespaces)) else {
            try fail("Could not parse the launched iOS pid from simctl output: \(output)")
        }
        return pid
    }
}
