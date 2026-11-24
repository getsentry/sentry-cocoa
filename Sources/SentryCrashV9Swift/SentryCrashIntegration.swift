#if !SDK_V10
#if SWIFT_PACKAGE && !SENTRY_BUILD_XCFRAMEWORK
@_spi(Private) import SentrySwift
#endif
internal import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

#if SWIFT_PACKAGE && !SENTRY_BUILD_XCFRAMEWORK
/// Compatibility entry point for callers importing the V9 crash adapter directly.
/// Use the callback in the main SDK module for new code.
@available(*, deprecated, message: "Use sentry_finishAndSaveTransaction() from the main SDK module instead.")
public func sentry_finishAndSaveTransaction() {
    // Preserve the adapter's Swift symbol, but only the main SDK owns the @_cdecl symbol.
    SentrySwift.sentry_finishAndSaveTransaction()
}
#endif

// MARK: - SentryCrashIntegration

final class SentryCrashIntegration<Dependencies: CrashIntegrationProvider>: NSObject, SentryIntegrationProtocol {

    private weak var options: Options?
    private var scopeObserver: SentryCrashScopeObserver?
    private var crashReporter: SentryCrashSwift
    private var installation: SentryCrashInstallationReporter?
    private var bridge: SentryCrashBridge
    private let currentRun: SentryCurrentRun

    // MARK: - Initialization

    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableCrashHandler else {
            SentryCrashV9Log.debug("Not going to enable \(Self.name) because enableCrashHandler is disabled.")
            return nil
        }

        self.options = options
        self.crashReporter = dependencies.crashReporter
        self.currentRun = dependencies.currentRun

        // Create facade before installing crash handler to ensure services are available
        self.bridge = SentryCrashBridge(
            notificationCenterWrapper: dependencies.notificationCenterWrapper,
            dateProvider: dependencies.dateProvider,
            crashReporter: dependencies.crashReporter
        )

        super.init()

        // Inject bridge into crash reporter so ObjC SentryCrash can access it
        crashReporter.setBridge(bridge)

        // Configure memory introspection based on options
        crashReporter.introspectMemory = options.enableMemoryIntrospection

        self.scopeObserver = SentryCrashScopeObserver(maxBreadcrumbs: Int(options.maxBreadcrumbs))

        startCrashHandler(options: options, dependencies: dependencies)

        configureScope()

        if options.enablePersistingTracesWhenCrashing {
            configureTracingWhenCrashing()
        }
    }

    // MARK: - SwiftIntegration

    static var name: String {
        "SentryCrashIntegration"
    }

    func uninstall() {
        if let installation = installation {
            installation.uninstall()
        }

        sentrycrash_setSaveTransaction(nil)

    #if !SDK_V10
        NotificationCenter.default.removeObserver(
            self,
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
    #endif

        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    // MARK: - Crash Handler

    private func startCrashHandler(options: Options, dependencies: Dependencies) {
        var enableSigtermReporting = false
        #if !os(watchOS)
        enableSigtermReporting = SentryCrashV9Backend.isSigtermReportingEnabled(in: options)
        #endif

        var enableReportingUncaughtExceptions = false
        #if os(macOS) && !SENTRY_NO_UI_FRAMEWORK
        if options.enableSwizzling {
            enableReportingUncaughtExceptions = options.enableUncaughtNSExceptionReporting
        }
        #endif

        var canSendReports = false

        if installation == nil {
            self.installation = dependencies.getCrashInstallationReporter(options)
            // Inject bridge into installation so it can access crashReporter
            installation?.setBridgeObject(bridge)
            canSendReports = true
        }

        sentrycrashcm_setEnableSigtermReporting(enableSigtermReporting)

        installation?.install(options.cacheDirectoryPath)

        // The crash reporter has loaded its state from disk. Set these flags so
        // SentrySDK.lastRunStatus returns a definitive answer and the integration
        // installer can determine the .didNotCrash case. We can't use
        // isIntegrationInstalled because it's set after init returns.
        if SentryDependencyContainer.sharedInstance().crashWrapper.crashedLastLaunch {
            SentrySDKInternal.fatalDetected = true
        }

        #if os(macOS) && !SENTRY_NO_UI_FRAMEWORK
        if enableReportingUncaughtExceptions {
            SentryUncaughtNSExceptions.configureCrashOnExceptions()
            SentryUncaughtNSExceptions.swizzleNSApplicationReportException()
            SentryUncaughtNSExceptions.swizzleNSApplicationCrashOnException()
        }
        #endif

        if options.experimental.enableUnhandledCPPExceptionsV2 {
            SentryCrashV9Log.debug("Enabling CppExceptionsV2 by swapping cxa_throw.")
            sentrycrashcm_cppexception_enable_swap_cxa_throw()
        }

        // Finalize the previous session before report processing or auto session tracking
        // can start, so the first fatal event can attach the crashed session.
        dependencies.finalizePreviousRunSession(
            options: options,
            crashedLastLaunch: dependencies.crashWrapper.crashedLastLaunch,
            activeDurationSinceLastCrash: dependencies.crashWrapper.activeDurationSinceLastCrash
        )

        // We only need to send all reports on the first initialization of SentryCrash. If
        // SentryCrash was deactivated there are no new reports to send. Furthermore, the
        // g_reportsPath in SentryCrashReportsStore gets set when SentryCrash is installed. In
        // production usage, this path is not supposed to change. When testing, this path can
        // change, and therefore, the initial set g_reportsPath can be deleted. sendAllReports calls
        // deleteAllReports, which fails it can't access g_reportsPath. We could fix SentryCrash or
        // just not call sendAllReports as it doesn't make sense to call it twice as described
        // above.
        if canSendReports {
            sendAllSentryCrashReportsInternal()
        }
    }

#if DEBUG // Test support.
    /// Sends all pending crash reports. Called internally during initialization,
    /// and exposed for testing purposes.
    func sendAllSentryCrashReports() {
        sendAllSentryCrashReportsInternal()
    }
#endif

    /// Sends all pending crash reports. Called internally during initialization.
    private func sendAllSentryCrashReportsInternal() {
        installation?.sendAllReports(completion: nil)
    }

    // MARK: - Scope Configuration

    private func configureScope() {
        // We need to make sure to set always the scope to SentryCrash so we have it in
        // case of a crash
        SentrySDKInternal.currentHub().configureScopeObject { [weak self] outerScope in
            guard let self = self, let outerScope = outerScope as? Scope, let options = self.options else { return }

            var userInfo = outerScope.serialize()

            // SentryCrashReportConverter.convertReportToEvent needs the release name, dist, and
            // environment of the SentryOptions in the UserInfo. When SentryCrash records a crash it
            // writes the UserInfo into SentryCrashField_User of the report.
            // SentryCrashReportConverter.initWithReport loads the contents of SentryCrashField_User
            // into self.userContext and convertReportToEvent can map the release name, dist, and
            // environment to the SentryEvent. Fixes GH-581 and GH-5260.
            userInfo["release"] = options.releaseName
            userInfo["dist"] = options.dist
            if userInfo["environment"] == nil {
                userInfo["environment"] = options.environment
            }

            // Crashes don't use the attributes field, we remove them to avoid uploading them
            // unnecessarily.
            userInfo.removeValue(forKey: "attributes")

            // The run ID links the crash report to the reports of other event sources, such as
            // MetricKit, that describe the same run.
            userInfo[SentryCurrentRun.userInfoKey] = self.currentRun.id.rawValue

            crashReporter.userInfo = userInfo

            if let scopeObserver = self.scopeObserver {
                outerScope.add(scopeObserver)
            }
        }

#if !SDK_V10
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(currentLocaleDidChange),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
#endif

        updateLowPowerModeContext(ProcessInfo.processInfo)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerStateDidChange(notification:)),
            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

#if !SDK_V10
    // Exposed to objc for the NotificationCenter in configureScope()
    @objc private func currentLocaleDidChange() {
        SentrySDKInternal.currentHub().configureScopeObject { rawScope in
            guard let scope = rawScope as? Scope else { return }
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
#endif

    @objc private func powerStateDidChange(notification: Notification) {
        let processInfo = if let notificationProcessInfo = notification.object as? ProcessInfo {
            notificationProcessInfo
        } else {
            ProcessInfo.processInfo
        }

        updateLowPowerModeContext(processInfo)
    }

    private func updateLowPowerModeContext(_ processInfo: ProcessInfo) {
        let isLowPowerMode = processInfo.isLowPowerModeEnabled
        SentrySDKInternal.currentHub().configureScopeObject { rawScope in
            guard let scope = rawScope as? Scope else { return }
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

    // MARK: - Tracing Configuration

    private func configureTracingWhenCrashing() {
        // A direct cross-module conversion of the @_cdecl function to a C function pointer
        // makes Swift emit a second thunk with the same C symbol. Use a noncapturing closure.
        #if SWIFT_PACKAGE && !SENTRY_BUILD_XCFRAMEWORK
        sentrycrash_setSaveTransaction { SentrySwift.sentry_finishAndSaveTransaction() }
        #else
        sentrycrash_setSaveTransaction { sentry_finishAndSaveTransaction() }
        #endif
    }
}

#if !SWIFT_PACKAGE || SENTRY_BUILD_XCFRAMEWORK
extension SentryCrashIntegration: SwiftIntegration {}
#endif
#endif // !SDK_V10
