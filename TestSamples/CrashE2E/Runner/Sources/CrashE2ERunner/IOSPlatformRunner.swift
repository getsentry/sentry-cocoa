import Foundation

final class IOSPlatformRunner {
    private let config: Config
    private let processRunner: ProcessRunner
    private let fileManager = FileManager.default
    private let bundleID = "io.sentry.tests.CrashE2E.iOS"

    private(set) var deviceID = ""
    private(set) var xcodebuildDestination = ""
    private var installedDerivedDataPath: URL?

    init(config: Config, processRunner: ProcessRunner) {
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
        }
    }

    private func installApp(derivedDataPath: URL) throws {
        let appPath = derivedDataPath
            .appendingPathComponent("Build/Products/Debug-iphonesimulator/CrashE2E-iOS.app", isDirectory: true)
        guard fileManager.fileExists(atPath: appPath.path) else {
            try fail("iOS app not found: \(appPath.path)")
        }

        log("Installing CrashE2E-iOS on \(deviceID).")
        try processRunner.run("xcrun", ["simctl", "terminate", deviceID, bundleID], captureOutput: true, allowFailure: true)
        try processRunner.run("xcrun", ["simctl", "uninstall", deviceID, bundleID], captureOutput: true, allowFailure: true)
        try processRunner.run("xcrun", ["simctl", "install", deviceID, appPath.path])
    }

    func runScenarios() throws {
        var failures: [String] = []
        for scenario in config.scenarios {
            do {
                let derivedDataPath = self.derivedDataPath(for: scenario)
                if installedDerivedDataPath != derivedDataPath {
                    try installApp(derivedDataPath: derivedDataPath)
                    installedDerivedDataPath = derivedDataPath
                }
                try runScenario(scenario)
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

    private func bootSimulator(_ udid: String) throws {
        log("Booting iOS simulator \(udid).")
        try processRunner.run("xcrun", ["simctl", "boot", udid], captureOutput: true, allowFailure: true)
        try processRunner.run("xcrun", ["simctl", "bootstatus", udid, "-b"], captureOutput: true, timeout: 180)
    }

    private func runScenario(_ scenario: Scenario) throws {
        log("iOS scenario: \(scenario.rawValue)")
        let container = try dataContainer()
        let markerPath = managedRuntimeMarkerPath(for: scenario, container: container)
        try cleanCache(container: container)
        if let markerPath {
            try fileManager.removeItemIfExists(at: markerPath)
        }
        try processRunner.run("xcrun", ["simctl", "terminate", deviceID, bundleID], captureOutput: true, allowFailure: true)

        let launchResult = try launchApp(arguments: crashLaunchArguments(for: scenario, markerPath: markerPath))
        try assertLaunchSucceeded(launchResult, scenario: scenario, launchType: "crash")
        log("iOS crash launch exited with \(launchResult.summary). Waiting for termination.")

        guard try waitForAppToStop(timeout: 25) else {
            try fail("iOS app did not terminate for scenario: \(scenario.rawValue)")
        }

        try drainPreviousCrash(for: scenario)
        try ScenarioEventAsserter.assertScenarioEvent(
            scenario,
            cacheRoot: container.appendingPathComponent("Library/Caches", isDirectory: true),
            platform: "ios",
            artifactsDir: config.artifactsDir
        )
        if let markerPath {
            try ManagedRuntimeSignalMarker.assertExists(at: markerPath, platform: "ios")
        }
    }

    private func drainPreviousCrash(for scenario: Scenario) throws {
        log("Relaunching iOS app to drain previous crash.")
        let result = try launchApp(arguments: ["--scenario", "drain", "--exit-after", "3"])
        try assertLaunchSucceeded(result, scenario: scenario, launchType: "drain")
        _ = try waitForAppToStop(timeout: 15)
    }

    private func launchApp(arguments: [String]) throws -> ProcessResult {
        try processRunner.run(
            "xcrun",
            ["simctl", "launch", deviceID, bundleID, "--io.sentry.disable-http-transport"] + arguments,
            captureOutput: true,
            timeout: 30,
            allowFailure: true
        )
    }

    private func assertLaunchSucceeded(_ result: ProcessResult, scenario: Scenario,
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
        try fileManager.removeItemIfExists(at: container.appendingPathComponent("Library/Caches/io.sentry", isDirectory: true))
    }

    private func dataContainer() throws -> URL {
        let path = try processRunner.runOutput("xcrun", ["simctl", "get_app_container", deviceID, bundleID, "data"])
        guard !path.isEmpty else {
            try fail("Could not determine iOS app data container for \(bundleID)")
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private func waitForAppToStop(timeout: TimeInterval) throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if try !isAppRunning() {
                return true
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return false
    }

    private func isAppRunning() throws -> Bool {
        let output = try processRunner.runOutput(
            "xcrun",
            ["simctl", "spawn", deviceID, "launchctl", "list"],
            allowFailure: true
        )
        return output.contains(bundleID)
    }
}
