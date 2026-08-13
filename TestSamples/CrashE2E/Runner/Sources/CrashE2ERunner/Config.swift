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

enum Reporter: String, CaseIterable {
    case sentryCrash = "SentryCrash"
    case ksCrash = "KSCrash"

    init?(caseInsensitive value: String) {
        guard let reporter = Self.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(value) == .orderedSame }) else {
            return nil
        }
        self = reporter
    }

    var iOSScheme: String {
        switch self {
        case .sentryCrash:
            return "CrashE2E-iOS"
        case .ksCrash:
            return "CrashE2E-iOS-KSCrash"
        }
    }

    var macOSScheme: String {
        switch self {
        case .sentryCrash:
            return "CrashE2E-macOS"
        case .ksCrash:
            return "CrashE2E-macOS-KSCrash"
        }
    }

    var iOSBundleID: String {
        switch self {
        case .sentryCrash:
            return "io.sentry.tests.CrashE2E.iOS"
        case .ksCrash:
            return "io.sentry.tests.CrashE2E.KSCrash.iOS"
        }
    }

    var iOSAppName: String {
        "\(iOSScheme).app"
    }

    var macOSExecutableName: String {
        macOSScheme
    }
}

enum Scenario: String, CaseIterable {
    case signal
    case nsException = "ns-exception"
    case nsExceptionSubclass = "ns-exception-subclass"
    case cppExceptionV1 = "cpp-exception-v1"
    case cppExceptionV2 = "cpp-exception-v2"
    case unityCxaThrow = "unity-cxa-throw"
    case unityCxaThrowV2 = "unity-cxa-throw-v2"
    case objcObject = "objc-object"
    case objcObjectAfterCaughtCPP = "objc-object-after-caught-cpp"
    case binaryImages = "binary-images"
    case ignoredSignal = "ignored-signal"
    case managedRuntimeSignalChain = "managed-runtime-signal-chain"
    case managedRuntimePreSDKSignal = "managed-runtime-pre-sdk-signal"
    case managedRuntimeClosedSignal = "managed-runtime-closed-signal"
    case managedRuntimeReinitSignal = "managed-runtime-reinit-signal"
    case swiftAsyncCPPExceptionV2Off = "swift-async-cpp-exception-v2-off"
    case swiftAsyncCPPExceptionV2On = "swift-async-cpp-exception-v2-on"
    case ksCrashPerReportRetry = "kscrash-per-report-retry"

    static let defaultScenarios: [Scenario] = [
        .signal,
        .nsException,
        .nsExceptionSubclass,
        // Keep the public option-off path reporter-neutral. KSCrash should continue reporting an
        // uncaught C++ exception without throw-site swapping even though it has no "V1" backend.
        .cppExceptionV1,
        .cppExceptionV2,
        // Current Sentry Unity does not enable C++ V2, so this exercises the named-symbol
        // compatibility shim in V1/fallback context. Preserve the shim, not V1's weak report shape.
        .unityCxaThrow,
        // Runs with C++ V2 enabled and strict modern-backend assertions. Current SentryCrash is
        // expected to fail this scenario; use --keep-going to continue the default run.
        .objcObject,
        .objcObjectAfterCaughtCPP,
        .binaryImages,
        .ignoredSignal,
        .managedRuntimeSignalChain,
        .managedRuntimePreSDKSignal,
        .managedRuntimeClosedSignal,
        .managedRuntimeReinitSignal,
        .swiftAsyncCPPExceptionV2Off,
        .swiftAsyncCPPExceptionV2On
    ]

    static let ksCrashDefaultScenarios = defaultScenarios + [
        .unityCxaThrowV2,
        .ksCrashPerReportRetry
    ]

    var requiresManagedRuntimeBuild: Bool {
        switch self {
        case .managedRuntimeSignalChain, .managedRuntimePreSDKSignal, .managedRuntimeClosedSignal,
             .managedRuntimeReinitSignal:
            return true
        case .signal, .nsException, .nsExceptionSubclass, .cppExceptionV1, .cppExceptionV2,
             .unityCxaThrow, .unityCxaThrowV2, .objcObject, .objcObjectAfterCaughtCPP,
             .binaryImages, .ignoredSignal, .swiftAsyncCPPExceptionV2Off,
             .swiftAsyncCPPExceptionV2On, .ksCrashPerReportRetry:
            return false
        }
    }

    var expectsCrashTermination: Bool {
        switch self {
        case .ignoredSignal:
            return false
        case .signal, .nsException, .nsExceptionSubclass, .cppExceptionV1, .cppExceptionV2,
             .unityCxaThrow, .unityCxaThrowV2, .objcObject, .objcObjectAfterCaughtCPP,
             .binaryImages, .managedRuntimeSignalChain, .managedRuntimePreSDKSignal,
             .managedRuntimeClosedSignal, .managedRuntimeReinitSignal,
             .swiftAsyncCPPExceptionV2Off, .swiftAsyncCPPExceptionV2On, .ksCrashPerReportRetry:
            return true
        }
    }

    var expectsEvent: Bool {
        switch self {
        case .managedRuntimePreSDKSignal, .managedRuntimeClosedSignal, .ignoredSignal:
            return false
        case .signal, .nsException, .nsExceptionSubclass, .cppExceptionV1, .cppExceptionV2,
             .unityCxaThrow, .unityCxaThrowV2, .objcObject, .objcObjectAfterCaughtCPP,
             .binaryImages, .managedRuntimeSignalChain, .managedRuntimeReinitSignal,
             .swiftAsyncCPPExceptionV2Off, .swiftAsyncCPPExceptionV2On, .ksCrashPerReportRetry:
            return true
        }
    }

    var requiresKSCrash: Bool {
        self == .unityCxaThrowV2 || self == .ksCrashPerReportRetry
    }

    var requiresCrashE2ETestHook: Bool {
        self == .ksCrashPerReportRetry
    }
}

struct Config {
    let directories: Directories
    var platform: Platform = .all
    var reporter: Reporter = .sentryCrash
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
      --reporter <SentryCrash|KSCrash>    Crash reporter to test (default: SentryCrash)
      --scenarios <space/comma list>      Scenarios to run (SentryCrash default: "\(defaultScenarios)")
                                          KSCrash also defaults to unity-cxa-throw-v2 and kscrash-per-report-retry.
                                          Known scenarios: \(knownScenarios)
      --ios-destination <destination>     xcodebuild iOS destination (default: auto-selected simulator id)
      --ios-device-id <device-id>         simctl device id (default: auto-select booted/preferred iPhone simulator)
      --derived-data-path <path>          DerivedData path (default: \(defaults.derivedDataPath.path))
      --skip-build                        Reuse existing build products
      --quiet-build                       Pass -quiet to xcodebuild
      --keep-artifacts                    Keep artifacts/cache directories generated by this run
      --keep-going, -k                    Continue running remaining scenarios after a scenario failure
                                          Alias: --continue-on-error
      --artifacts-dir <path>              Artifact directory (default: \(defaults.artifactsDir.path))
      --help                              Show this help
    """
}
