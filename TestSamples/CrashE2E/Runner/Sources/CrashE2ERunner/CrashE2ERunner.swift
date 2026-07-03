import Foundation

final class CrashE2ERunner {
    private let config: Config
    private let processRunner: ProcessRunner
    private let fileManager = FileManager.default
    private let iOSRunner: IOSPlatformRunner
    private let macOSRunner: MacOSPlatformRunner

    init(config: Config, processRunner: ProcessRunner = ProcessRunner()) {
        self.config = config
        self.processRunner = processRunner
        self.iOSRunner = IOSPlatformRunner(config: config, processRunner: processRunner)
        self.macOSRunner = MacOSPlatformRunner(config: config, processRunner: processRunner)
    }

    func run() throws {
        try validateInputs()

        let appleCrashReporterDialogSuppressor = AppleCrashReporterDialogSuppressor(processRunner: processRunner)
        try appleCrashReporterDialogSuppressor.suppress()
        defer { appleCrashReporterDialogSuppressor.restore() }

        try preparePlatforms()
        try buildProject()
        try runPlatforms()
        log("✅ Crash E2E completed.")
    }

    private func validateInputs() throws {
        try processRunner.requireTool("xcodebuild")
        try processRunner.requireTool("xcodegen")
        try processRunner.requireTool("launchctl")

        if shouldRunIOS {
            try processRunner.requireTool("xcrun")
        }
    }

    private func preparePlatforms() throws {
        if shouldRunIOS {
            try iOSRunner.prepareSimulator()
        }
    }

    private func buildProject() throws {
        if config.skipBuild {
            log("Skipping build.")
            return
        }

        log("Generating CrashE2E Xcode project.")
        try processRunner.run(
            "xcodegen",
            ["--spec", "TestSamples/CrashE2E/CrashE2E.yml"],
            workingDirectory: config.directories.repoRoot
        )

        if shouldBuildNormalVariant {
            try buildVariant(derivedDataPath: config.derivedDataPath, label: "default", extraBuildSettings: [])
        }
        if shouldBuildManagedRuntimeVariant {
            try buildVariant(
                derivedDataPath: config.managedRuntimeDerivedDataPath,
                label: "managed runtime",
                extraBuildSettings: ["GCC_PREPROCESSOR_DEFINITIONS=$(inherited) SENTRY_CRASH_MANAGED_RUNTIME=1"]
            )
        }
    }

    private func buildVariant(derivedDataPath: URL, label: String, extraBuildSettings: [String]) throws {
        if shouldRunIOS {
            try buildIOSApp(derivedDataPath: derivedDataPath, label: label,
                            extraBuildSettings: extraBuildSettings)
        }
        if shouldRunMacOS {
            try buildMacOSApp(derivedDataPath: derivedDataPath, label: label,
                              extraBuildSettings: extraBuildSettings)
        }
    }

    private func buildIOSApp(derivedDataPath: URL, label: String, extraBuildSettings: [String]) throws {
        log("Building CrashE2E-iOS (\(label)).")
        try xcodebuild([
            "-project", config.directories.crashE2EDir.appendingPathComponent("CrashE2E.xcodeproj").path,
            "-scheme", "CrashE2E-iOS",
            "-configuration", "Debug",
            "-destination", iOSRunner.xcodebuildDestination,
            "-derivedDataPath", derivedDataPath.path,
            "CODE_SIGNING_REQUIRED=NO"
        ] + extraBuildSettings + ["build"])
    }

    private func buildMacOSApp(derivedDataPath: URL, label: String, extraBuildSettings: [String]) throws {
        log("Building CrashE2E-macOS (\(label)).")
        try xcodebuild([
            "-project", config.directories.crashE2EDir.appendingPathComponent("CrashE2E.xcodeproj").path,
            "-scheme", "CrashE2E-macOS",
            "-configuration", "Debug",
            "-destination", "platform=macOS",
            "-derivedDataPath", derivedDataPath.path,
            "CODE_SIGNING_REQUIRED=NO"
        ] + extraBuildSettings + ["build"])
    }

    private func xcodebuild(_ arguments: [String]) throws {
        var args = arguments
        if config.quietBuild {
            args.insert("-quiet", at: 0)
        }
        try processRunner.run("xcodebuild", args)
    }

    private func runPlatforms() throws {
        // Always start from a clean directory so stale artifacts don't affect this run.
        try resetArtifactsDirectory()
        defer { cleanupArtifactsDirectory() }

        var failures: [String] = []
        if shouldRunIOS {
            do {
                try iOSRunner.runScenarios()
            } catch {
                if config.keepGoing {
                    failures.append(String(describing: error))
                } else {
                    throw error
                }
            }
        }
        if shouldRunMacOS {
            do {
                try macOSRunner.runScenarios()
            } catch {
                if config.keepGoing {
                    failures.append(String(describing: error))
                } else {
                    throw error
                }
            }
        }

        if !failures.isEmpty {
            try fail("Crash E2E completed with failures:\n\(failures.map { "- \($0)" }.joined(separator: "\n"))")
        }
    }

    private func resetArtifactsDirectory() throws {
        try fileManager.removeItemIfExists(at: config.artifactsDir)
        try fileManager.ensureDirectory(at: config.artifactsDir)
    }

    private func cleanupArtifactsDirectory() {
        guard !config.keepArtifacts else {
            log("Artifacts are in \(config.artifactsDir.path).")
            return
        }

        do {
            try fileManager.removeItemIfExists(at: config.artifactsDir)
        } catch {
            log("Failed to remove artifacts directory \(config.artifactsDir.path): \(error)")
        }
    }

    private var shouldBuildNormalVariant: Bool {
        config.scenarios.contains { !$0.requiresManagedRuntimeBuild }
    }

    private var shouldBuildManagedRuntimeVariant: Bool {
        config.scenarios.contains { $0.requiresManagedRuntimeBuild }
    }

    private var shouldRunIOS: Bool {
        config.platform == .all || config.platform == .ios
    }

    private var shouldRunMacOS: Bool {
        config.platform == .all || config.platform == .macos
    }
}
