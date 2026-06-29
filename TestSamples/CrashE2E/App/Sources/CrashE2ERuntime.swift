import Darwin
import Foundation
import Sentry

enum CrashE2EScenario: String {
    case idle
    case drain
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
}

struct CrashE2EConfiguration {
    let scenario: CrashE2EScenario
    let cacheDirectoryPath: String?
    let managedHandlerMarkerPath: String?
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

        let exitAfterSeconds = Self.value(after: "--exit-after", in: arguments)
            .flatMap(TimeInterval.init)

        return CrashE2EConfiguration(
            scenario: scenario,
            cacheDirectoryPath: cacheDirectoryPath,
            managedHandlerMarkerPath: managedHandlerMarkerPath,
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

enum CrashE2ERuntime {
    static let configuration = CrashE2EConfiguration.fromProcessInfo()
    private static var binaryImageBeforeSDKPath: String?
    private static var binaryImageAfterSDKPath: String?

    static func startSDK() {
        NSLog("CrashE2E - starting SDK with scenario: \(configuration.scenario.rawValue)")
        triggerPreSDKSignalIfNeeded()
        installFakeManagedRuntimeHandlerIfNeeded()
        loadBinaryImageBeforeSDKIfNeeded()
        startConfiguredSDK()
        NSLog("CrashE2E - SDK started")
    }

    static func runSelectedScenario() {
        switch configuration.scenario {
        case .idle:
            NSLog("CrashE2E - idle")
            scheduleExitIfRequested()
        case .drain:
            NSLog("CrashE2E - drain previous crash")
            scheduleExitIfRequested(defaultDelay: 3.0)
        case .managedRuntimePreSDKSignal:
            abortBecausePreSDKScenarioReturned()
        case .signal, .nsException, .cppExceptionV1, .cppExceptionV2, .unityCxaThrow, .objcObject,
             .binaryImages, .managedRuntimeSignalChain, .managedRuntimeClosedSignal,
             .managedRuntimeReinitSignal, .swiftAsyncCPPExceptionV2Off, .swiftAsyncCPPExceptionV2On:
            NSLog("CrashE2E - will trigger scenario: \(configuration.scenario.rawValue)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                CrashE2ECrashTriggers.trigger(configuration.scenario)
            }
        }
    }

    static func runSelectedScenarioSynchronously() {
        switch configuration.scenario {
        case .idle:
            NSLog("CrashE2E - idle")
            sleepThenExit(configuration.exitAfterSeconds ?? 0)
        case .drain:
            NSLog("CrashE2E - drain previous crash")
            sleepThenExit(configuration.exitAfterSeconds ?? 3.0)
        case .managedRuntimePreSDKSignal:
            abortBecausePreSDKScenarioReturned()
        case .signal, .nsException, .cppExceptionV1, .cppExceptionV2, .unityCxaThrow, .objcObject,
             .binaryImages, .managedRuntimeSignalChain, .managedRuntimeClosedSignal,
             .managedRuntimeReinitSignal, .swiftAsyncCPPExceptionV2Off, .swiftAsyncCPPExceptionV2On:
            NSLog("CrashE2E - will trigger scenario synchronously: \(configuration.scenario.rawValue)")
            Thread.sleep(forTimeInterval: 0.5)
            CrashE2ECrashTriggers.trigger(configuration.scenario)
        }
    }

    static func closeAndRestartSDK() {
        NSLog("CrashE2E - closing and restarting SDK")
        SentrySDK.close()
        startConfiguredSDK()
        NSLog("CrashE2E - SDK restarted")
    }

    private static func startConfiguredSDK() {
        SentrySDK.start { options in
            options.dsn = "https://public@example.com/1"
            options.debug = true
            options.enableAutoSessionTracking = true
            options.enableSwizzling = true
            options.enableAppHangTracking = false
            #if os(macOS)
            options.enableUncaughtNSExceptionReporting = true
            #endif
            options.maxCacheItems = 100

            // Keep cpp-exception-v1 and unity-cxa-throw in the current SentryCrash V1/fallback
            // context. V1 is being sunset and is not a KSCrash parity target, but Unity's current
            // native shim does not enable Sentry Cocoa's C++ V2 option, so the V1-context Unity
            // scenario remains a temporary compatibility/counterexample check for the old backend.
            if configuration.scenario == .cppExceptionV2
                || configuration.scenario == .objcObject
                || configuration.scenario == .swiftAsyncCPPExceptionV2Off
                || configuration.scenario == .swiftAsyncCPPExceptionV2On {
                options.experimental.enableUnhandledCPPExceptionsV2 = true
            }

            if configuration.scenario == .swiftAsyncCPPExceptionV2On {
                options.swiftAsyncStacktraces = true
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

    private static func installFakeManagedRuntimeHandlerIfNeeded() {
        switch configuration.scenario {
        case .managedRuntimeSignalChain, .managedRuntimeClosedSignal, .managedRuntimeReinitSignal:
            installFakeManagedRuntimeHandler()
        case .idle, .drain, .signal, .nsException, .cppExceptionV1, .cppExceptionV2, .unityCxaThrow,
             .objcObject, .binaryImages, .managedRuntimePreSDKSignal, .swiftAsyncCPPExceptionV2Off,
             .swiftAsyncCPPExceptionV2On:
            return
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
        if let cacheDirectoryPath = configuration.cacheDirectoryPath {
            return URL(fileURLWithPath: cacheDirectoryPath, isDirectory: true)
                .appendingPathComponent("crash-e2e-binary-images.json")
        }

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        guard let cacheURL = caches.first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return cacheURL.appendingPathComponent("crash-e2e-binary-images.json")
    }

    private static func installFakeManagedRuntimeHandler() {
        guard let markerPath = configuration.managedHandlerMarkerPath else {
            NSLog("CrashE2E - missing managed runtime handler marker path")
            Darwin.abort()
        }
        markerPath.withCString { CrashE2EInstallFakeManagedRuntimeSignalHandler($0) }
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
