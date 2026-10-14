import Foundation

final class IOSPlatformRunner {
    let config: Config
    let processRunner: any CommandExecuting
    let fileManager = FileManager.default

    private(set) var deviceID = ""
    private(set) var xcodebuildDestination = ""
    private var installedDerivedDataPath: URL?
    var appProcess: ProcessExitObserver?
    var launchArtifacts: URL?
    var scenarioName = "app"
    var launchCount = 0

    init(config: Config, processRunner: any CommandExecuting) {
        self.config = config
        self.processRunner = processRunner
    }

    func prepareSimulator() throws {
        let selection = try IOSSimulatorResolver(processRunner: processRunner).resolve(
            deviceID: config.iosDeviceID,
            destination: config.iosDestination
        )
        deviceID = selection.device.udid
        xcodebuildDestination = selection.xcodebuildDestination

        log("Using iOS simulator: \(selection.device.name) / \(selection.device.runtimeDescription) (\(selection.device.udid))")

        if selection.device.state != "Booted" {
            try bootSimulator(selection.device.udid)
            try waitForSimulatorToBoot(selection.device.udid)
        }
    }

    private func reinstallApp(derivedDataPath: URL) throws {
        let appPath = derivedDataPath
            .appendingPathComponent("Build/Products/Debug-iphonesimulator/\(config.reporter.iOSAppName)", isDirectory: true)
        guard fileManager.fileExists(atPath: appPath.path) else {
            try fail("iOS app not found: \(appPath.path)")
        }

        log("Installing \(config.reporter.iOSScheme) on \(deviceID).")

        try terminateApp()
        try uninstallApp()
        try installApp(at: appPath)
    }

    private func uninstallApp() throws {
        try processRunner.run("xcrun", ["simctl", "uninstall", deviceID, bundleID], captureOutput: true, allowFailure: true)
    }

    private func installApp(at appPath: URL) throws {
        try processRunner.run("xcrun", ["simctl", "install", deviceID, appPath.path])
    }

    func runScenarios() throws {
        var failures: [String] = []

        for scenario in config.scenarios {
            // Cleanup precedes known-failure classification and keep-going handling. Its
            // own failure must abort even when the scenario has a documented SDK gap.
            let outcome = try runScenarioWithCleanup(scenario)
            do {
                try runAllowingKnownFailure(scenario, reporter: config.reporter, platform: "ios") {
                    try outcome.get()
                }
            } catch {
                if config.keepGoing {
                    let message = "iOS/\(scenario.rawValue): \(error)"
                    failures.append(message)
                    log("❌ \(message)")
                } else {
                    throw error
                }
            }
        }

        if !failures.isEmpty {
            try fail(failures.joined(separator: "\n"))
        }
    }

    private func runScenarioWithCleanup(_ scenario: Scenario) throws -> Result<Void, Error> {
        do {
            let derivedDataPath = self.derivedDataPath(for: scenario)
            if installedDerivedDataPath != derivedDataPath {
                try reinstallApp(derivedDataPath: derivedDataPath)
                installedDerivedDataPath = derivedDataPath
            }

            try runScenario(scenario)

            return .success(())
        } catch {
            let scenarioError = error

            do {
                try terminateApp()
            } catch {
                try fail("\(scenarioError)\nCould not stop iOS app after failure: \(error)")
            }

            preserveFailureCache(scenario: scenario)

            return .failure(scenarioError)
        }
    }

    private func bootSimulator(_ udid: String) throws {
        log("Booting iOS simulator \(udid).")
        try processRunner.run("xcrun", ["simctl", "boot", udid], captureOutput: true, allowFailure: true)
    }

    private func waitForSimulatorToBoot(_ udid: String) throws {
        try processRunner.run("xcrun", ["simctl", "bootstatus", udid, "-b"], captureOutput: true, timeout: 180)
    }

    private func runScenario(_ scenario: Scenario) throws {
        log("iOS scenario: \(scenario.rawValue)")

        scenarioName = scenario.rawValue
        try terminateApp()

        let container = try dataContainer()
        try cleanCache(container: container)

        if scenario == .ksCrashPerReportRetry {
            try runKSCrashRetryScenario(container: container)
            return
        }

        if scenario == .sigterm {
            try runSigtermScenario(container: container)
            return
        }

        let markerPath = managedRuntimeMarkerPath(for: scenario, container: container)
        if let markerPath {
            try fileManager.removeItemIfExists(at: markerPath)
        }

        let launchResult = try launchApp(arguments: crashLaunchArguments(for: scenario, markerPath: markerPath))
        try assertLaunchSucceeded(launchResult, scenario: scenario, launchType: "crash")

        log("iOS crash launch exited with \(launchResult.summary). Waiting for termination.")

        guard try waitForAppToStop(timeout: 25) else {
            try fail("iOS app did not terminate for scenario: \(scenario.rawValue)")
        }

        let cacheRoot = container.appendingPathComponent("Library/Caches", isDirectory: true)
        try assertCrashLaunchArtifacts(for: scenario, cacheRoot: cacheRoot)

        try StoredCrashReports.copyUndrained(
            from: cacheRoot,
            platform: "ios",
            scenario: scenario,
            artifactsDir: config.artifactsDir
        )

        try drainPreviousCrash(for: scenario)

        try ScenarioEventAsserter.assertScenarioEvent(
            scenario,
            cacheRoot: cacheRoot,
            platform: "ios",
            artifactsDir: config.artifactsDir
        )

        if let markerPath {
            try ManagedRuntimeSignalMarker.assertExists(at: markerPath, platform: "ios")
        }
    }

    private func assertCrashLaunchArtifacts(for scenario: Scenario, cacheRoot: URL) throws {
        try CrashTimeAttachmentsAsserter.assertPayloadIfNeeded(
            scenario: scenario,
            cacheDirectory: cacheRoot,
            platform: "ios"
        )
        try CrashTimeReplayAsserter.assertCheckpointIfNeeded(
            scenario: scenario,
            cacheDirectory: cacheRoot,
            platform: "ios"
        )
        try CrashTimeReplayAsserter.assertCaptureRecrashIfNeeded(
            scenario: scenario,
            cacheDirectory: cacheRoot,
            platform: "ios"
        )
        try RethrownNSExceptionAsserter.assertCrashLaunchEvidenceIfNeeded(
            scenario: scenario,
            cacheRoot: cacheRoot,
            platform: "ios",
            artifactsDir: config.artifactsDir
        )
        try MemoryIntrospectionAsserter.assertStoredReportIfNeeded(
            scenario: scenario,
            cacheRoot: cacheRoot,
            platform: "ios"
        )
    }

    func drainPreviousCrash(for scenario: Scenario) throws {
        log("Relaunching iOS app to drain previous crash.")
        let result = try launchApp(arguments: ["--scenario", "drain", "--exit-after", "3"])
        try assertLaunchSucceeded(result, scenario: scenario, launchType: "drain")
        guard try waitForAppToStop(timeout: 60) else {
            try fail("iOS drain app did not terminate for scenario: \(scenario.rawValue)")
        }
    }

    func assertLaunchSucceeded(_ result: ProcessResult, scenario: Scenario,
                               launchType: String) throws {
        if result.timedOut {
            try fail("iOS \(launchType) simctl launch timed out for scenario: \(scenario.rawValue)")
        }
        guard result.succeeded else {
            try failLaunch(result, scenario: scenario, launchType: launchType)
        }
    }

    private func failLaunch(_ result: ProcessResult, scenario: Scenario,
                            launchType: String) throws -> Never {
        var message = "iOS \(launchType) simctl launch failed for scenario: \(scenario.rawValue) (\(result.summary))"
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stderr.isEmpty {
            message += "\n\(stderr)"
        }
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stdout.isEmpty {
            message += "\nstdout:\n\(stdout)"
        }
        try fail(message)
    }

    private func crashLaunchArguments(for scenario: Scenario, markerPath: URL?) -> [String] {
        var arguments = ["--scenario", scenario.rawValue]
        if let markerPath {
            arguments += ["--managed-handler-marker", markerPath.path]
        }
        return arguments
    }

    private func managedRuntimeMarkerPath(for scenario: Scenario, container: URL) -> URL? {
        guard scenario.requiresManagedRuntimeBuild else { return nil }
        return container
            .appendingPathComponent("Library/Caches", isDirectory: true)
            .appendingPathComponent("crash-e2e-managed-runtime-signal.marker")
    }

    private func derivedDataPath(for scenario: Scenario) -> URL {
        scenario.requiresManagedRuntimeBuild ? config.managedRuntimeDerivedDataPath : config.derivedDataPath
    }

    private func cleanCache(container: URL) throws {
        let cacheRoot = container.appendingPathComponent("Library/Caches", isDirectory: true)
        try fileManager.removeItemIfExists(
            at: cacheRoot.appendingPathComponent("io.sentry", isDirectory: true)
        )
        try fileManager.removeItemIfExists(
            at: cacheRoot.appendingPathComponent("KSCrash", isDirectory: true)
        )
        try fileManager.removeItemIfExists(
            at: cacheRoot.appendingPathComponent("SentryCrash", isDirectory: true)
        )
        try fileManager.removeItemIfExists(
            at: cacheRoot.appendingPathComponent("crash-e2e-replay-checkpoint")
        )
    }

    func dataContainer() throws -> URL {
        let result = try processRunner.run("xcrun", ["simctl", "get_app_container", deviceID, bundleID, "data"],
                                           captureOutput: true, timeout: 10)
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            try fail("Could not determine iOS app data container for \(bundleID)")
        }

        return URL(fileURLWithPath: path, isDirectory: true)
    }

    var bundleID: String {
        config.reporter.iOSBundleID
    }

}
