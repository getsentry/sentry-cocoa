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
    case nsExceptionRethrow = "ns-exception-rethrow"
    case nsExceptionSubclass = "ns-exception-subclass"
    case cppExceptionV1 = "cpp-exception-v1"
    case cppExceptionV2 = "cpp-exception-v2"
    case cppExceptionV2DynamicImage = "cpp-exception-v2-dynamic-image"
    case unityCxaThrow = "unity-cxa-throw"
    case unityCxaThrowV2 = "unity-cxa-throw-v2"
    case objcObject = "objc-object"
    case objcObjectAfterCaughtCPP = "objc-object-after-caught-cpp"
    case binaryImages = "binary-images"
    case ignoredSignal = "ignored-signal"
    case sigterm
    case managedRuntimeSignalChain = "managed-runtime-signal-chain"
    case managedRuntimePreSDKSignal = "managed-runtime-pre-sdk-signal"
    case managedRuntimeClosedSignal = "managed-runtime-closed-signal"
    case managedRuntimeReinitSignal = "managed-runtime-reinit-signal"
    case swiftAsyncCPPExceptionV2Off = "swift-async-cpp-exception-v2-off"
    case swiftAsyncCPPExceptionV2On = "swift-async-cpp-exception-v2-on"
    case ksCrashPerReportRetry = "kscrash-per-report-retry"
    case mallocZoneLockedSignal = "malloc-zone-locked-signal"
    case crashTimeScope = "crash-time-scope"
    case crashTimeAttachments = "crash-time-attachments"
    case crashTimeReplay = "crash-time-replay"
    case crashTimeReplayAttachmentCrash = "crash-time-replay-attachment-crash"
    case memoryIntrospectionEnabled = "memory-introspection-enabled"
    case memoryIntrospectionDisabled = "memory-introspection-disabled"
    case memoryIntrospectionDefault = "memory-introspection-default"

    static let defaultScenarios: [Scenario] = [
        .signal,
        .nsException,
        .nsExceptionRethrow,
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
        // SIGTERM is a graceful-shutdown request, not a crash. Both reporters must let the process
        // terminate without writing a report or an event, and the next launch must not be
        // classified as crashed. V9 honors enableSigtermReporting (off here); V10 has no option.
        .sigterm,
        .managedRuntimeSignalChain,
        .managedRuntimePreSDKSignal,
        .managedRuntimeClosedSignal,
        .managedRuntimeReinitSignal,
        .swiftAsyncCPPExceptionV2Off,
        .swiftAsyncCPPExceptionV2On,
        // enableMemoryIntrospection must reach the crash-time writer of both reporters. A marker
        // string that only memory introspection can discover must appear in the stored report and
        // event when enabled, and be absent when disabled or left at the default.
        .memoryIntrospectionEnabled,
        .memoryIntrospectionDisabled,
        .memoryIntrospectionDefault
    ]

    static let ksCrashDefaultScenarios = defaultScenarios + [
        .cppExceptionV2DynamicImage,
        .unityCxaThrowV2,
        .ksCrashPerReportRetry,
        .crashTimeScope,
        .crashTimeAttachments,
        .crashTimeReplay,
        .crashTimeReplayAttachmentCrash
    ]

    var requiresManagedRuntimeBuild: Bool {
        switch self {
        case .managedRuntimeSignalChain, .managedRuntimePreSDKSignal, .managedRuntimeClosedSignal,
             .managedRuntimeReinitSignal:
            return true
        default:
            return false
        }
    }

    var expectsCrashTermination: Bool {
        self != .ignoredSignal
    }

    var expectsEvent: Bool {
        switch self {
        case .managedRuntimePreSDKSignal, .managedRuntimeClosedSignal, .ignoredSignal, .sigterm:
            return false
        default:
            return true
        }
    }

    var requiresKSCrash: Bool {
        self == .cppExceptionV2DynamicImage || self == .unityCxaThrowV2
            || self == .ksCrashPerReportRetry || self == .crashTimeScope
            || self == .crashTimeAttachments || self == .crashTimeReplay
            || self == .crashTimeReplayAttachmentCrash
    }

    var requiresCrashE2ETestHook: Bool {
        self == .ksCrashPerReportRetry || self == .crashTimeAttachments || self == .crashTimeReplay
            || self == .crashTimeReplayAttachmentCrash
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
    let knownScenarios = Scenario.allCases.map(\.rawValue).joined(separator: ", ")
    return """
    Usage: run-crash-e2e.sh [options]
      --platform <all|ios|macos>          Platforms to run (default: all)
      --reporter <SentryCrash|KSCrash>    Crash reporter to test (default: SentryCrash)
      --scenarios <space/comma list>      Scenarios to run (uses reporter-specific defaults).
                                          Default sets: Scenario.defaultScenarios and
                                          Scenario.ksCrashDefaultScenarios in Config.swift.
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
