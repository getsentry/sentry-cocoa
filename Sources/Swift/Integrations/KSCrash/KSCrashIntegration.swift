@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

//// MARK: - C Callback Function
//
///// Global function to finish and save transaction when a crash occurs.
///// This function is called from C crash reporting code.
//@_cdecl("sentry_finishAndSaveTransaction")
//public func sentry_finishAndSaveTransaction() {
//    let scope = SentrySDKInternal.currentHub().scope as Scope
//    guard let span = scope.getCastedInternalSpan() else {
//        SentrySDKLog.debug("No span found in current scope, skipping transaction finish and save")
//        return
//    }
//    span.tracer?.finishForCrash()
//}

// MARK: - Dependency Provider

///// Provides dependencies for `SentryCrashIntegration`.
//typealias CrashIntegrationProvider = SentryCrashReporterProvider & CrashIntegrationSessionHandlerBuilder & CrashInstallationReporterBuilder & DateProviderProvider & NotificationCenterProvider

// MARK: - SentryCrashIntegration

final class KSCrashIntegration<Dependencies: CrashIntegrationProvider>: NSObject, SwiftIntegration {
    private weak var options: Options?

    private var scopeObserver: SentryCrashScopeObserver

//    private var sessionHandler: SentryCrashIntegrationSessionHandler?
//    private var scopeObserver: SentryCrashScopeObserver?
//    private var crashReporter: SentryCrashSwift // this is the main 'wrapper' around SentryCrash (KSCrash)
//    private var installation: SentryCrashInstallationReporter?
//    private var bridge: SentryCrashBridge

    // MARK: - Initialization

    // swiftlint:disable function_body_length
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableCrashHandler else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableCrashHandler is disabled.")
            return nil
        }

//        self.options = options
//        self.crashReporter = dependencies.crashReporter
//
//        // Create facade before installing crash handler to ensure services are available
//        self.bridge = SentryCrashBridge(
//            notificationCenterWrapper: dependencies.notificationCenterWrapper,
//            dateProvider: dependencies.dateProvider,
//            crashReporter: dependencies.crashReporter
//        )
        self.scopeObserver = SentryCrashScopeObserver(maxBreadcrumbs: Int(options.maxBreadcrumbs))

        super.init()

//        // Inject bridge into crash reporter so ObjC SentryCrash can access it
//        crashReporter.setBridge(bridge)
//
//        self.sessionHandler = dependencies.getCrashIntegrationSessionBuilder(options, bridge: bridge)
//
//        guard /*self.sessionHandler != nil,*/ self.scopeObserver != nil else {
//            SentrySDKLog.warning("Failed to initialize SentryCrashIntegration dependencies")
//            return nil
//        }
//
//        var enableSigtermReporting = false
//        #if !os(watchOS)
//        enableSigtermReporting = options.enableSigtermReporting
//        #endif
//
//        var enableUncaughtNSExceptionReporting = false
//        #if os(macOS) && !SENTRY_NO_UI_FRAMEWORK
//        if options.enableSwizzling {
//            enableUncaughtNSExceptionReporting = options.enableUncaughtNSExceptionReporting
//        }
//        #endif
//
//        startCrashHandler(
//            cacheDirectory: options.cacheDirectoryPath,
//            enableSigtermReporting: enableSigtermReporting,
//            enableReportingUncaughtExceptions: enableUncaughtNSExceptionReporting,
//            enableCppExceptionsV2: options.experimental.enableUnhandledCPPExceptionsV2,
//            dependencies: dependencies
//        )
//
//        configureScope()
//
//        if options.enablePersistingTracesWhenCrashing {
//            configureTracingWhenCrashing()
//        }
    }
    // swiftlint:enable function_body_length

    // MARK: - SwiftIntegration

    static var name: String {
        "KSCrashIntegration"
    }

    func uninstall() {
    }

    // MARK: - Scope
    private func configureScope() {
        // We need to make sure to set always the scope to SentryCrash so we have it in
        // case of a crash
        SentrySDKInternal.currentHub().configureScope { [weak self] outerScope in
            guard let self = self, let options = self.options else { return }

            var userInfo = outerScope.serialize()

            // TODO: can this be achieved with KSCrash Sidecar or Report filters?

            // SentryCrashReportConverter.convertReportToEvent needs the release name and
            // the dist of the SentryOptions in the UserInfo. When SentryCrash records a
            // crash it writes the UserInfo into SentryCrashField_User of the report.
            // SentryCrashReportConverter.initWithReport loads the contents of
            // SentryCrashField_User into self.userContext and convertReportToEvent can map
            // the release name and dist to the SentryEvent. Fixes GH-581
            userInfo["release"] = options.releaseName
            userInfo["dist"] = options.dist

            // Crashes don't use the attributes field, we remove them to avoid uploading them
            // unnecessarily.
            userInfo.removeValue(forKey: "attributes")

//            crashReporter.userInfo = userInfo // TODO: this

            outerScope.add(scopeObserver)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(currentLocaleDidChange),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )

        if #available(macOS 12.0, *) {
            updateLowPowerModeContext(ProcessInfo.processInfo)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(powerStateDidChange(notification:)),
                name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
                object: nil
            )
        }
    }

    // Exposed to objc for the NotificationCenter in configureScope()
    @objc private func currentLocaleDidChange() {
        SentrySDKInternal.currentHub().configureScope { scope in
            var device: [String: Any]
            let contextDictionary = scope.contextDictionary
            if let existingDevice = contextDictionary[SENTRY_CONTEXT_DEVICE_KEY] as? [String: Any] {
                device = existingDevice
            } else {
                device = [:]
            }

            let locale = Locale.autoupdatingCurrent.identifier
            device["locale"] = locale

            scope.setContext(value: device, key: SENTRY_CONTEXT_DEVICE_KEY)
        }
    }

    @objc @available(macOS 12.0, *)
    private func powerStateDidChange(notification: Notification) {
        let processInfo = if let notificationProcessInfo = notification.object as? ProcessInfo {
            notificationProcessInfo
        } else {
            ProcessInfo.processInfo
        }

        updateLowPowerModeContext(processInfo)
    }

    @available(macOS 12.0, *)
    private func updateLowPowerModeContext(_ processInfo: ProcessInfo) {
        let isLowPowerMode = processInfo.isLowPowerModeEnabled
        SentrySDKInternal.currentHub().configureScope { scope in
            var device: [String: Any]
            let contextDictionary = scope.contextDictionary
            if let existingDevice = contextDictionary[SENTRY_CONTEXT_DEVICE_KEY] as? [String: Any] {
                device = existingDevice
            } else {
                device = [:]
            }

            device["low_power_mode"] = isLowPowerMode

            scope.setContext(value: device, key: SENTRY_CONTEXT_DEVICE_KEY)
        }
    }
}
