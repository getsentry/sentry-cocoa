import Foundation

final class MacOSPlatformRunner {
    private let config: Config
    private let processRunner: ProcessRunner
    private let fileManager = FileManager.default

    init(config: Config, processRunner: ProcessRunner) {
        self.config = config
        self.processRunner = processRunner
    }

    func runScenarios() throws {
        var failures: [String] = []
        for scenario in config.scenarios {
            do {
                try runScenario(scenario)
            } catch {
                if config.keepGoing {
                    let message = "macOS/\(scenario.rawValue): \(error)"
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

    private func runScenario(_ scenario: Scenario) throws {
        let derivedDataPath = self.derivedDataPath(for: scenario)
        let executable = try macOSExecutable(derivedDataPath: derivedDataPath)
        let cacheDir = config.artifactsDir.appendingPathComponent("macos-cache-\(scenario.rawValue)", isDirectory: true)
        let markerPath = managedRuntimeMarkerPath(for: scenario, cacheDir: cacheDir)
        try fileManager.removeItemIfExists(at: cacheDir)
        try fileManager.ensureDirectory(at: cacheDir)

        log("macOS scenario: \(scenario.rawValue)")
        try runCrashLaunch(scenario, executable: executable, cacheDir: cacheDir,
                           markerPath: markerPath, derivedDataPath: derivedDataPath)
        try runDrainLaunch(scenario, executable: executable, cacheDir: cacheDir,
                           derivedDataPath: derivedDataPath)
        try ScenarioEventAsserter.assertScenarioEvent(
            scenario,
            cacheRoot: cacheDir,
            platform: "macos",
            artifactsDir: config.artifactsDir
        )
        if let markerPath {
            try ManagedRuntimeSignalMarker.assertExists(at: markerPath, platform: "macos")
        }
    }

    private func macOSExecutable(derivedDataPath: URL) throws -> URL {
        let executable = derivedDataPath
            .appendingPathComponent("Build/Products/Debug/CrashE2E-macOS")
        guard fileManager.isExecutableFile(atPath: executable.path) else {
            try fail("macOS executable not found: \(executable.path)")
        }
        return executable
    }

    private func crashAppEnvironment(derivedDataPath: URL) -> [String: String] {
        ["DYLD_FRAMEWORK_PATH": derivedDataPath.appendingPathComponent("Build/Products/Debug").path]
    }

    private func managedRuntimeMarkerPath(for scenario: Scenario, cacheDir: URL) -> URL? {
        guard scenario.requiresManagedRuntimeBuild else { return nil }
        return cacheDir.appendingPathComponent("crash-e2e-managed-runtime-signal.marker")
    }

    private func derivedDataPath(for scenario: Scenario) -> URL {
        scenario.requiresManagedRuntimeBuild ? config.managedRuntimeDerivedDataPath : config.derivedDataPath
    }

    private func crashArguments(_ scenario: Scenario, cacheDir: URL, markerPath: URL?) -> [String] {
        var arguments = ["--io.sentry.disable-http-transport", "--cache-dir", cacheDir.path,
                         "--scenario", scenario.rawValue]
        if let markerPath {
            arguments += ["--managed-handler-marker", markerPath.path]
        }
        return arguments
    }

    private func runCrashLaunch(_ scenario: Scenario, executable: URL, cacheDir: URL,
                                markerPath: URL?, derivedDataPath: URL) throws {
        let crashLog = config.artifactsDir.appendingPathComponent("macos-\(scenario.rawValue)-crash.log")
        let result = try processRunner.run(
            executable.path,
            crashArguments(scenario, cacheDir: cacheDir, markerPath: markerPath),
            environment: crashAppEnvironment(derivedDataPath: derivedDataPath),
            outputFile: crashLog,
            timeout: 30,
            allowFailure: true
        )

        if result.timedOut {
            try fail("macOS app did not terminate for scenario: \(scenario.rawValue) (\(result.summary))")
        }
        if result.succeeded {
            try fail("macOS app exited successfully for crash scenario: \(scenario.rawValue)")
        }
        log("macOS crash process exited with \(result.summary).")
    }

    private func runDrainLaunch(_ scenario: Scenario, executable: URL, cacheDir: URL,
                                derivedDataPath: URL) throws {
        log("Relaunching macOS app to drain previous crash.")
        let drainLog = config.artifactsDir.appendingPathComponent("macos-\(scenario.rawValue)-drain.log")
        let result = try processRunner.run(
            executable.path,
            ["--io.sentry.disable-http-transport", "--cache-dir", cacheDir.path,
             "--scenario", "drain", "--exit-after", "3"],
            environment: crashAppEnvironment(derivedDataPath: derivedDataPath),
            outputFile: drainLog,
            timeout: 20,
            allowFailure: true
        )
        if result.timedOut {
            try fail("macOS drain app did not terminate for scenario: \(scenario.rawValue) (\(result.summary))")
        }
    }
}
