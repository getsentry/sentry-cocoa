import Darwin
import Foundation
import Sentry

// swiftlint:disable file_length

enum CrashE2EScenario: String {
    case idle
    case drain
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
    case closedSignal = "closed-signal"
    case reinitSignal = "reinit-signal"
    case closedNSException = "closed-ns-exception"
    case managedRuntimeSignalChain = "managed-runtime-signal-chain"
    case managedRuntimeHandledSignal = "managed-runtime-handled-signal"
    case managedRuntimeIgnoreNextSignalSwift = "managed-runtime-ignore-next-signal-swift"
    case managedRuntimeIgnoreNextSignalObjC = "managed-runtime-ignore-next-signal-objc"
    case managedRuntimePreSDKSignal = "managed-runtime-pre-sdk-signal"
    case managedRuntimeClosedSignal = "managed-runtime-closed-signal"
    case managedRuntimeReinitSignal = "managed-runtime-reinit-signal"
    case swiftAsyncCPPExceptionV2Off = "swift-async-cpp-exception-v2-off"
    case swiftAsyncCPPExceptionV2On = "swift-async-cpp-exception-v2-on"
    case ksCrashRetryReportA = "kscrash-retry-report-a"
    case ksCrashRetryReportB = "kscrash-retry-report-b"
    case mallocZoneLockedSignal = "malloc-zone-locked-signal"
    case crashTimeScope = "crash-time-scope"
    case crashTimeAttachments = "crash-time-attachments"
    case crashTimeReplay = "crash-time-replay"
    case crashTimeReplayAttachmentCrash = "crash-time-replay-attachment-crash"
    case memoryIntrospectionEnabled = "memory-introspection-enabled"
    case memoryIntrospectionDisabled = "memory-introspection-disabled"
    case memoryIntrospectionDefault = "memory-introspection-default"
}

struct CrashE2EConfiguration {
    let scenario: CrashE2EScenario
    let cacheDirectoryPath: String?
    let managedHandlerMarkerPath: String?
    let processingCompleteMarkerPath: String?
    let exitAfterSeconds: TimeInterval?

    static func fromProcessInfo(_ processInfo: ProcessInfo = .processInfo) -> CrashE2EConfiguration {
        let arguments = processInfo.arguments
        let environment = processInfo.environment

        let scenarioName = Self.value(after: "--scenario", in: arguments)
            ?? environment["SENTRY_CRASH_E2E_SCENARIO"]
            ?? CrashE2EScenario.idle.rawValue
        let scenario = CrashE2EScenario(rawValue: scenarioName) ?? .idle

        let cacheDirectoryPath = Self.value(after: "--cache-dir", in: arguments)
            ?? environment["SENTRY_CRASH_E2E_CACHE_DIR"]

        let managedHandlerMarkerPath = Self.value(after: "--managed-handler-marker", in: arguments)
            ?? environment["SENTRY_CRASH_E2E_MANAGED_HANDLER_MARKER"]

        let processingCompleteMarkerPath = Self.value(
            after: "--io.sentry.crash-e2e-kscrash-processing-complete",
            in: arguments
        )

        let exitAfterSeconds = Self.value(after: "--exit-after", in: arguments)
            .flatMap(TimeInterval.init)

        return CrashE2EConfiguration(
            scenario: scenario,
            cacheDirectoryPath: cacheDirectoryPath,
            managedHandlerMarkerPath: managedHandlerMarkerPath,
            processingCompleteMarkerPath: processingCompleteMarkerPath,
            exitAfterSeconds: exitAfterSeconds
        )
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return nil }
        return arguments[valueIndex]
    }
}

// swiftlint:disable type_body_length
enum CrashE2ERuntime {
    static let configuration = CrashE2EConfiguration.fromProcessInfo()
    private static var binaryImageBeforeSDKPath: String?
    private static var binaryImageAfterSDKPath: String?

    static func startSDK() {
        NSLog("CrashE2E - starting SDK with scenario: \(configuration.scenario.rawValue)")
        triggerPreSDKSignalIfNeeded()
        installIgnoredSignalHandlerIfNeeded()
        installFakeManagedRuntimeHandlerIfNeeded()
        installUncaughtNSExceptionMarkerIfNeeded()
        loadBinaryImageBeforeSDKIfNeeded()
        startConfiguredSDK()
        writeLastRunMarkerIfNeeded()
        CrashE2EScopePopulation.populateLiveIfNeeded()
        logCrashTimeHooksIfNeeded()
        NSLog("CrashE2E - SDK started")
    }

    static func runSelectedScenario() {
        switch configuration.scenario {
        case .idle:
            NSLog("CrashE2E - idle")
            scheduleExitIfRequested()
        case .drain:
            NSLog("CrashE2E - drain previous crash")
            if configuration.processingCompleteMarkerPath == nil {
                scheduleExitIfRequested(defaultDelay: 3.0)
            } else {
                scheduleExitAfterProcessingCompletes()
            }
        case .managedRuntimePreSDKSignal:
            abortBecausePreSDKScenarioReturned()
        case .sigterm:
            waitForExternalSigterm()
        case .signal, .nsException, .nsExceptionRethrow, .nsExceptionSubclass, .cppExceptionV1,
             .cppExceptionV2, .cppExceptionV2DynamicImage, .unityCxaThrow, .unityCxaThrowV2,
             .objcObject, .objcObjectAfterCaughtCPP, .binaryImages, .ignoredSignal,
             .closedSignal, .reinitSignal, .closedNSException, .managedRuntimeSignalChain,
             .managedRuntimeHandledSignal, .managedRuntimeIgnoreNextSignalSwift,
             .managedRuntimeIgnoreNextSignalObjC, .managedRuntimeClosedSignal,
             .managedRuntimeReinitSignal, .swiftAsyncCPPExceptionV2Off,
             .swiftAsyncCPPExceptionV2On, .ksCrashRetryReportA, .ksCrashRetryReportB,
             .mallocZoneLockedSignal, .crashTimeScope, .crashTimeAttachments,
             .crashTimeReplay, .crashTimeReplayAttachmentCrash,
             .memoryIntrospectionEnabled, .memoryIntrospectionDisabled, .memoryIntrospectionDefault:
            NSLog("CrashE2E - will trigger scenario: \(configuration.scenario.rawValue)")
            scheduleCrashAfterProcessingCompletesIfRequested()
        }
    }

    static func runSelectedScenarioSynchronously() {
        switch configuration.scenario {
        case .idle:
            NSLog("CrashE2E - idle")
            sleepThenExit(configuration.exitAfterSeconds ?? 0)
        case .drain:
            NSLog("CrashE2E - drain previous crash")
            if configuration.processingCompleteMarkerPath != nil {
                waitForProcessingCompletionOrAbort()
                sleepThenExit(0)
            }
            sleepThenExit(configuration.exitAfterSeconds ?? 3.0)
        case .managedRuntimePreSDKSignal:
            abortBecausePreSDKScenarioReturned()
        case .sigterm:
            waitForExternalSigtermSynchronously()
        case .signal, .nsException, .nsExceptionRethrow, .nsExceptionSubclass, .cppExceptionV1,
             .cppExceptionV2, .cppExceptionV2DynamicImage, .unityCxaThrow, .unityCxaThrowV2,
             .objcObject, .objcObjectAfterCaughtCPP, .binaryImages, .ignoredSignal,
             .closedSignal, .reinitSignal, .closedNSException, .managedRuntimeSignalChain,
             .managedRuntimeHandledSignal, .managedRuntimeIgnoreNextSignalSwift,
             .managedRuntimeIgnoreNextSignalObjC, .managedRuntimeClosedSignal,
             .managedRuntimeReinitSignal, .swiftAsyncCPPExceptionV2Off,
             .swiftAsyncCPPExceptionV2On, .ksCrashRetryReportA, .ksCrashRetryReportB,
             .mallocZoneLockedSignal, .crashTimeScope, .crashTimeAttachments,
             .crashTimeReplay, .crashTimeReplayAttachmentCrash,
             .memoryIntrospectionEnabled, .memoryIntrospectionDisabled, .memoryIntrospectionDefault:
            NSLog("CrashE2E - will trigger scenario synchronously: \(configuration.scenario.rawValue)")
            waitForProcessingCompletionOrAbort()
            Thread.sleep(forTimeInterval: 0.5)
            CrashE2ECrashTriggers.trigger(configuration.scenario)
        }
    }

    static func closeAndRestartSDK() {
        NSLog("CrashE2E - closing and restarting SDK")
        SentrySDK.close()
        startConfiguredSDK()
        CrashE2EScopePopulation.populateLiveIfNeeded()
        logCrashTimeHooksIfNeeded()
        NSLog("CrashE2E - SDK restarted")
    }

    private static func startConfiguredSDK() {
        SentrySDK.start { options in
            options.dsn = "https://public@example.com/1"
            options.debug = true
            options.enableAutoSessionTracking = true
            options.enableSwizzling = true
            #if !SDK_V10
            options.enableAppHangTracking = false
            #endif // !SDK_V10
            #if os(macOS)
            options.enableUncaughtNSExceptionReporting = true
            #endif
            options.maxCacheItems = 100

            if configuration.scenario == .crashTimeScope {
                options.environment = "crash-e2e-environment"
                options.dist = "crash-e2e-dist"
                options.initialScope = { scope in
                    CrashE2EScopePopulation.applyInitial(to: scope)
                    return scope
                }
            }

            // Keep cpp-exception-v1 in the public option-off configuration for both reporters.
            // KSCrash has no "V1" implementation, but its standard terminate monitor must preserve
            // uncaught C++ reporting when throw-site swapping is disabled. unity-cxa-throw matches
            // Sentry Unity's option-off behavior; unity-cxa-throw-v2 is the KSCrash-only companion.
            if configuration.scenario == .cppExceptionV2
                || configuration.scenario == .cppExceptionV2DynamicImage
                || configuration.scenario == .unityCxaThrowV2
                || configuration.scenario == .objcObject
                || configuration.scenario == .objcObjectAfterCaughtCPP
                || configuration.scenario == .swiftAsyncCPPExceptionV2Off
                || configuration.scenario == .swiftAsyncCPPExceptionV2On {
                options.experimental.enableUnhandledCPPExceptionsV2 = true
            }

            if configuration.scenario == .swiftAsyncCPPExceptionV2Off {
                options.swiftAsyncStacktraces = false
            } else if configuration.scenario == .swiftAsyncCPPExceptionV2On {
                options.swiftAsyncStacktraces = true
            }

            // The default scenario intentionally leaves the option untouched so it verifies the
            // public default rather than an explicit value.
            if configuration.scenario == .memoryIntrospectionEnabled {
                options.enableMemoryIntrospection = true
            } else if configuration.scenario == .memoryIntrospectionDisabled {
                options.enableMemoryIntrospection = false
            }

            if let cacheDirectoryPath = configuration.cacheDirectoryPath {
                options.cacheDirectoryPath = cacheDirectoryPath
            }
        }
    }

    private static func triggerPreSDKSignalIfNeeded() {
        guard configuration.scenario == .managedRuntimePreSDKSignal else { return }
        installFakeManagedRuntimeHandler()
        NSLog("CrashE2E - triggering managed runtime signal before SentrySDK.start")
        SentrySDK.crash()
        abortBecausePreSDKScenarioReturned()
    }

    private static func logCrashTimeHooksIfNeeded() {
        switch configuration.scenario {
        case .crashTimeAttachments:
            NSLog("CrashE2E - crash-time-attachments uses the SDK SENTRY_CRASH_E2E attachment hook")
        case .crashTimeReplay:
            NSLog("CrashE2E - crash-time-replay uses the SDK SENTRY_CRASH_E2E replay checkpoint hook")
        case .crashTimeReplayAttachmentCrash:
            NSLog(
                "CrashE2E - crash-time-replay-attachment-crash uses the SDK SENTRY_CRASH_E2E replay checkpoint and failing attachment hooks"
            )
        default:
            return
        }
    }

    private static func installUncaughtNSExceptionMarkerIfNeeded() {
        guard configuration.scenario == .nsExceptionRethrow else { return }
        let markerURL: URL
        if let cacheDirectoryPath = configuration.cacheDirectoryPath {
            markerURL = URL(fileURLWithPath: cacheDirectoryPath, isDirectory: true)
                .appendingPathComponent("crash-e2e-uncaught-nsexception.marker")
        } else {
            markerURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("crash-e2e-uncaught-nsexception.marker")
        }
        CrashE2EInstallUncaughtNSExceptionMarker(markerURL.path)
    }

    private static func installIgnoredSignalHandlerIfNeeded() {
        guard configuration.scenario == .ignoredSignal else { return }
        NSLog("CrashE2E - installing SIG_IGN for SIGPIPE before SentrySDK.start")
        signal(SIGPIPE, SIG_IGN)
    }

    private static func installFakeManagedRuntimeHandlerIfNeeded() {
        switch configuration.scenario {
        case .managedRuntimeHandledSignal:
            installFakeManagedRuntimeHandler(forwardSignal: false)
        case .managedRuntimeSignalChain, .managedRuntimeIgnoreNextSignalSwift,
             .managedRuntimeIgnoreNextSignalObjC, .managedRuntimeClosedSignal,
             .managedRuntimeReinitSignal:
            installFakeManagedRuntimeHandler()
        default:
            return
        }
    }

    static func loadCPPExceptionImageAfterSDK() {
        guard configuration.scenario == .cppExceptionV2DynamicImage else { return }
        let requestedPath = dynamicBinaryImagePath(named: "After")
        guard requestedPath.withCString({ CrashE2ELoadDynamicBinaryImage($0, 1) }) != nil else {
            NSLog("CrashE2E - failed to load C++ exception image after SDK start")
            Darwin.abort()
        }
    }

    static func loadBinaryImageAfterSDKForCrashScenario() {
        guard configuration.scenario == .binaryImages else { return }
        let requestedPath = dynamicBinaryImagePath(named: "After")
        guard let loadedImage = requestedPath.withCString({ CrashE2ELoadDynamicBinaryImage($0, 1) }) else {
            NSLog("CrashE2E - failed to load binary image after SDK start")
            Darwin.abort()
        }
        binaryImageAfterSDKPath = loadedImage
        writeBinaryImageMarkerFile()
        SentrySDK.configureScope { scope in
            scope.setContext(value: [
                "before_sdk_path": binaryImageBeforeSDKPath ?? "",
                "after_sdk_path": loadedImage
            ], key: "crash_e2e_binary_images")
        }
    }

    private static func loadBinaryImageBeforeSDKIfNeeded() {
        guard configuration.scenario == .binaryImages else { return }
        let requestedPath = dynamicBinaryImagePath(named: "Before")
        guard let loadedImage = requestedPath.withCString({ CrashE2ELoadDynamicBinaryImage($0, 0) }) else {
            NSLog("CrashE2E - failed to load binary image before SDK start")
            Darwin.abort()
        }
        binaryImageBeforeSDKPath = loadedImage
    }

    private static func dynamicBinaryImagePath(named name: String) -> String {
        let dylibName = "CrashE2EDynamicImage\(name).dylib"
        #if os(iOS)
        let rootURL = Bundle.main.bundleURL.appendingPathComponent(dylibName)
        if FileManager.default.fileExists(atPath: rootURL.path) {
            return rootURL.path
        }
        let frameworksURL = Bundle.main.privateFrameworksURL
            ?? Bundle.main.bundleURL.appendingPathComponent("Frameworks", isDirectory: true)
        return frameworksURL.appendingPathComponent(dylibName).path
        #else
        let executableDirectory = Bundle.main.executableURL?.deletingLastPathComponent()
            ?? URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        return executableDirectory.appendingPathComponent(dylibName).path
        #endif
    }

    private static func writeBinaryImageMarkerFile() {
        guard let beforeSDKPath = binaryImageBeforeSDKPath,
              let afterSDKPath = binaryImageAfterSDKPath else {
            NSLog("CrashE2E - missing dynamic binary image marker paths")
            Darwin.abort()
        }

        do {
            let markerURL = try binaryImageMarkerURL()
            let marker = [
                "before_sdk_path": beforeSDKPath,
                "after_sdk_path": afterSDKPath
            ]
            let data = try JSONSerialization.data(withJSONObject: marker, options: [.sortedKeys])
            try data.write(to: markerURL, options: [.atomic])
        } catch {
            NSLog("CrashE2E - failed to write binary image marker: \(error)")
            Darwin.abort()
        }
    }

    private static func binaryImageMarkerURL() throws -> URL {
        try cacheMarkerURL(named: "crash-e2e-binary-images.json")
    }

    private static func installFakeManagedRuntimeHandler(forwardSignal: Bool = true) {
        guard let markerPath = configuration.managedHandlerMarkerPath else {
            NSLog("CrashE2E - missing managed runtime handler marker path")
            Darwin.abort()
        }
        markerPath.withCString {
            CrashE2EInstallFakeManagedRuntimeSignalHandler($0, forwardSignal ? 1 : 0)
        }
    }

    private static func abortBecausePreSDKScenarioReturned() -> Never {
        NSLog("CrashE2E - pre-SDK managed runtime scenario returned unexpectedly")
        Darwin.abort()
    }

    private static func scheduleExitIfRequested(defaultDelay: TimeInterval? = nil) {
        guard let delay = configuration.exitAfterSeconds ?? defaultDelay else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            NSLog("CrashE2E - exiting after drain delay")
            SentrySDK.close()
            Darwin.exit(0)
        }
    }

    private static func sleepThenExit(_ delay: TimeInterval) -> Never {
        if delay > 0 {
            Thread.sleep(forTimeInterval: delay)
        }
        NSLog("CrashE2E - exiting")
        SentrySDK.close()
        Darwin.exit(0)
    }
}
// swiftlint:enable type_body_length
