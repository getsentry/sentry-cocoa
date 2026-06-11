import Foundation

struct Directories {
    let crashE2EDir: URL
    let repoRoot: URL

    static func discover(environment: [String: String] = ProcessInfo.processInfo.environment) -> Directories {
        if let crashE2EPath = environment["CRASH_E2E_DIR"],
           let repoRootPath = environment["SENTRY_COCOA_REPO_ROOT"] {
            return Directories(
                crashE2EDir: absoluteURL(crashE2EPath),
                repoRoot: absoluteURL(repoRootPath)
            )
        }

        let sourceFile = URL(fileURLWithPath: #filePath).standardizedFileURL
        let crashE2EDir = sourceFile
            .deletingLastPathComponent() // CrashE2ERunner
            .deletingLastPathComponent() // Sources
            .deletingLastPathComponent() // Runner
            .deletingLastPathComponent() // CrashE2E
        let repoRoot = crashE2EDir
            .deletingLastPathComponent() // TestSamples
            .deletingLastPathComponent() // repo root
        return Directories(crashE2EDir: crashE2EDir, repoRoot: repoRoot)
    }
}

enum Platform: String {
    case all
    case ios
    case macos
}

enum Scenario: String, CaseIterable {
    case signal
    case nsException = "ns-exception"
    case cppExceptionV1 = "cpp-exception-v1"
    case cppExceptionV2 = "cpp-exception-v2"
    case unityCxaThrow = "unity-cxa-throw"
    case objcObject = "objc-object"
    case binaryImages = "binary-images"
    case managedRuntimeSignalChain = "managed-runtime-signal-chain"
    case managedRuntimePreSDKSignal = "managed-runtime-pre-sdk-signal"
    case managedRuntimeClosedSignal = "managed-runtime-closed-signal"
    case managedRuntimeReinitSignal = "managed-runtime-reinit-signal"
    case swiftAsyncCPPExceptionV2Off = "swift-async-cpp-exception-v2-off"
    case swiftAsyncCPPExceptionV2On = "swift-async-cpp-exception-v2-on"

    static let defaultScenarios: [Scenario] = [
        .signal,
        .nsException,
        // Current-backend-only counterexample. Drop/deactivate when running against KSCrash;
        // V1 is sunsetting and is not a KSCrash parity target.
        .cppExceptionV1,
        .cppExceptionV2,
        // Current Sentry Unity does not enable C++ V2, so this exercises the named-symbol
        // compatibility shim in V1/fallback context. Preserve the shim, not V1's weak report shape.
        .unityCxaThrow,
        // Runs with C++ V2 enabled and strict modern-backend assertions. Current SentryCrash is
        // expected to fail this scenario; use --keep-going to continue the default run.
        .objcObject,
        .binaryImages,
        .managedRuntimeSignalChain,
        .managedRuntimePreSDKSignal,
        .managedRuntimeClosedSignal,
        .managedRuntimeReinitSignal,
        .swiftAsyncCPPExceptionV2Off,
        .swiftAsyncCPPExceptionV2On
    ]

    var requiresManagedRuntimeBuild: Bool {
        switch self {
        case .managedRuntimeSignalChain, .managedRuntimePreSDKSignal, .managedRuntimeClosedSignal,
             .managedRuntimeReinitSignal:
            return true
        case .signal, .nsException, .cppExceptionV1, .cppExceptionV2, .unityCxaThrow, .objcObject,
             .binaryImages, .swiftAsyncCPPExceptionV2Off, .swiftAsyncCPPExceptionV2On:
            return false
        }
    }

    var expectsEvent: Bool {
        switch self {
        case .managedRuntimePreSDKSignal, .managedRuntimeClosedSignal:
            return false
        case .signal, .nsException, .cppExceptionV1, .cppExceptionV2, .unityCxaThrow, .objcObject,
             .binaryImages, .managedRuntimeSignalChain, .managedRuntimeReinitSignal,
             .swiftAsyncCPPExceptionV2Off, .swiftAsyncCPPExceptionV2On:
            return true
        }
    }
}

struct Config {
    let directories: Directories
    var platform: Platform = .all
    var scenarios: [Scenario] = Scenario.defaultScenarios
    var iosDestination: String?
    var iosDeviceID: String?
    var derivedDataPath: URL
    var skipBuild = false
    var keepArtifacts = false
    var keepGoing = false
    var artifactsDir: URL
    var quietBuild = false

    var managedRuntimeDerivedDataPath: URL {
        derivedDataPath.appendingPathComponent("ManagedRuntime", isDirectory: true)
    }

    init(directories: Directories) {
        self.directories = directories
        self.derivedDataPath = directories.repoRoot
            .appendingPathComponent("DerivedData", isDirectory: true)
            .appendingPathComponent("CrashE2E", isDirectory: true)
        self.artifactsDir = directories.crashE2EDir.appendingPathComponent("artifacts", isDirectory: true)
    }

    static func parse(arguments: [String], directories: Directories) throws -> Config {
        var parser = ConfigArgumentParser(arguments: arguments, directories: directories)
        return try parser.parse()
    }
}

struct HelpRequested: Error {}

func usage(defaults: Config) -> String {
    let defaultScenarios = Scenario.defaultScenarios.map(\.rawValue).joined(separator: " ")
    let knownScenarios = Scenario.allCases.map(\.rawValue).joined(separator: ", ")
    return """
    Usage: run-crash-e2e.sh [options]
      --platform <all|ios|macos>          Platforms to run (default: all)
      --scenarios <space/comma list>      Scenarios to run (default: "\(defaultScenarios)")
                                          Known scenarios: \(knownScenarios)
      --ios-destination <destination>     xcodebuild iOS destination (default: auto-selected simulator id)
      --ios-device-id <device-id>         simctl device id (default: auto-select booted/preferred iPhone simulator)
      --derived-data-path <path>          DerivedData path (default: \(defaults.derivedDataPath.path))
      --skip-build                        Reuse existing build products
      --quiet-build                       Pass -quiet to xcodebuild
      --keep-artifacts                    Keep runner artifacts/cache directories
      --keep-going, -k                    Continue running remaining scenarios after a scenario failure
                                          Alias: --continue-on-error
      --artifacts-dir <path>              Artifact directory (default: \(defaults.artifactsDir.path))
      --help                              Show this help
    """
}
