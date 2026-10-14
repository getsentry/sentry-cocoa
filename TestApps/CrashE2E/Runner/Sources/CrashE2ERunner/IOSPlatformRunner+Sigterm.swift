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
        let pid = try ProcessExitObserver.launchedProcessIdentifier(stdout: launchResult.stdout, bundleID: bundleID)

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

}
