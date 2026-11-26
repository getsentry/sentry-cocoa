import Darwin
import Foundation

extension MacOSPlatformRunner {
    func runSigtermScenario(executable: URL, cacheDir: URL, derivedDataPath: URL) throws {
        let readyMarker = cacheDir.appendingPathComponent(SigtermScenarioConstants.readyMarkerFileName)
        try fileManager.removeItemIfExists(at: readyMarker)

        let crashLog = config.artifactsDir.appendingPathComponent("macos-sigterm-crash.log")
        let running = try processRunner.start(
            executable.path,
            ["--io.sentry.disable-http-transport", "--cache-dir", cacheDir.path,
             "--scenario", Scenario.sigterm.rawValue],
            environment: crashAppEnvironment(derivedDataPath: derivedDataPath),
            outputFile: crashLog
        )

        do {
            try SigtermScenarioAsserter.waitForReadyMarker(at: readyMarker, platform: "macos")
            try SigtermScenarioAsserter.sendSigterm(to: running.processIdentifier, platform: "macos")
        } catch {
            if running.isRunning {
                Darwin.kill(running.processIdentifier, SIGKILL)
            }
            _ = processRunner.wait(for: running, timeout: 5)
            throw error
        }

        let result = processRunner.wait(for: running, timeout: SigtermScenarioConstants.terminationTimeout)
        if result.timedOut {
            try fail("macOS app did not terminate after SIGTERM (\(result.summary))")
        }
        guard result.terminationReason == .uncaughtSignal, result.terminationStatus == SIGTERM else {
            try fail("macOS app should terminate with SIGTERM, but exited with \(result.summary)")
        }
        log("macOS SIGTERM process exited with \(result.summary).")

        try SigtermScenarioAsserter.assertNoStoredCrashReports(cacheRoot: cacheDir, platform: "macos")
        try runDrainLaunch(.sigterm, executable: executable, cacheDir: cacheDir,
                           derivedDataPath: derivedDataPath)
        try ScenarioEventAsserter.assertScenarioEvent(
            .sigterm,
            cacheRoot: cacheDir,
            platform: "macos",
            artifactsDir: config.artifactsDir
        )
        try SigtermScenarioAsserter.assertLastRunNotCrashed(cacheRoot: cacheDir, platform: "macos")
    }
}
