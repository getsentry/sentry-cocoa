@_implementationOnly import _SentryPrivate
import KSCrashRecording

// MARK: - C Callback

/// Finishes and saves the active transaction so it can be attached to the crash event.
/// Called from the KSCrash willWriteReportCallback (ObjC/C context).
@_cdecl("sentry_finishAndSaveTransaction")
func sentry_finishAndSaveTransaction() {
    let scope = SentrySDKInternal.currentHub().scope as Scope
    guard let span = scope.getCastedInternalSpan() else {
        SentrySDKLog.debug("No span found in current scope, skipping transaction finish and save")
        return
    }
    span.tracer?.finishForCrash()
}

// MARK: - Dependency Provider

/// Provides dependencies for `KSCrashIntegration`.
typealias KSCrashIntegrationProvider = KSCrashReporterProvider & KSCrashIntegrationSessionHandlerBuilder & CrashInstallationReporterBuilder

// MARK: - KSCrashIntegration

final class KSCrashIntegration<Dependencies: KSCrashIntegrationProvider>: NSObject, SwiftIntegration {
    private weak var options: Options?

    private let scopeObserver: SentryKSCrashScopeObserver
    private let crashReporter: SentryCrashReporter
    private let installation: SentryKSCrashInstallationReporter?

    // MARK: - Initialization

    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableCrashHandler else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableCrashHandler is disabled.")
            return nil
        }

        self.options = options

        self.crashReporter = dependencies.kscrashReporter
        self.scopeObserver = SentryKSCrashScopeObserver(maxBreadcrumbs: Int(options.maxBreadcrumbs))
        self.installation = dependencies.getCrashInstallationReporter(options)

        super.init()

        startCrashHandler(options: options, dependencies: dependencies)

        configureScope()
    }

    // MARK: - SwiftIntegration

    static var name: String {
        "KSCrashIntegration"
    }

    func uninstall() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )

        if #available(macOS 12.0, *) {
            NotificationCenter.default.removeObserver(
                self,
                name: .NSProcessInfoPowerStateDidChange,
                object: nil
            )
        }

        // KSCrash does not support uninstalling monitors after installation.
        // Clear userInfo so sensitive scope data is not retained in memory.
        KSCrash.shared.userInfo = nil
    }

    // MARK: - Crash Handler

    private func startCrashHandler(options: Options, dependencies: Dependencies) {
        let enableSigtermReporting: Bool
        #if !os(watchOS)
        enableSigtermReporting = options.enableSigtermReporting
        #else
        enableSigtermReporting = false
        #endif

        let config = SentryKSCrashConfigurationFactory.configuration(
            withInstallPath: options.cacheDirectoryPath,
            monitors: .productionSafeMinimal,
            enableSigTermMonitoring: enableSigtermReporting,
            enableSwapCxaThrow: options.experimental.enableUnhandledCPPExceptionsV2,
            persistTracesOnCrash: options.enablePersistingTracesWhenCrashing
        )

        do {
            try installation?.install(with: config)
        } catch {
            SentrySDKLog.debug("KSCrash Installation failed: \(error)")
        }

        // The crash reporter has loaded its state from disk. Set these flags so
        // SentrySDK.lastRunStatus returns a definitive answer and the integration
        // installer can determine the .didNotCrash case. We can't use
        // isIntegrationInstalled because it's set after init returns.
        SentrySDKInternal.crashReporterInstalled = true
        if SentryDependencyContainer.sharedInstance().crashWrapper.crashedLastLaunch {
            SentrySDKInternal.fatalDetected = true
        }

        #if os(macOS) && !SENTRY_NO_UI_FRAMEWORK
        if options.enableReportingUncaughtExceptions {
            SentryUncaughtNSExceptions.configureCrashOnExceptions()
            SentryUncaughtNSExceptions.swizzleNSApplicationReportException()
            SentryUncaughtNSExceptions.swizzleNSApplicationCrashOnException()
        }
        #endif

        // We need to send the crashed event together with the crashed session in the same envelope
        // to have proper statistics in release health. To achieve this we need both synchronously
        // in the hub. The crashed event is converted from a SentryCrashReport to an event in
        // SentryCrashReportSink and then passed to the SDK on a background thread. This process is
        // started with installing this integration. We need to end and delete the previous session
        // before being able to start a new session for the AutoSessionTrackingIntegration. The
        // SentryKSCrashIntegration is installed before the AutoSessionTrackingIntegration so there is
        // no guarantee if the crashed event is created before or after the
        // AutoSessionTrackingIntegration. By ending the previous session and storing it as crashed
        // in here we have the guarantee once the crashed event is sent to the hub it is already
        // there and the AutoSessionTrackingIntegration can work properly.
        //
        // This is a pragmatic and not the most optimal place for this logic.
        dependencies.getKSCrashIntegrationSessionHandler(options)?.endCurrentSessionIfRequired()

        installation?.sendAllReports(completion: nil)
    }

    // MARK: - Scope Configuration

    private func configureScope() {
        // We need to make sure to set always the scope to SentryCrash so we have it in
        // case of a crash
        SentrySDKInternal.currentHub().configureScope { [weak self] outerScope in
            guard let self, let options else { return }

            var userInfo = outerScope.serialize()

            // TODO: this comment is now outdated - update it to ensure accuracy before pushing
            // KSCrashReportConverter.convertReportToEvent needs the release name and
            // the dist of the Options in the UserInfo. When SentryCrash records a
            // crash it writes the UserInfo into SentryCrashField_User of the report.
            // KSCrashReportConverter.initWithReport loads the contents of
            // SentryCrashField_User into self.userContext and convertReportToEvent can map
            // the release name and dist to the SentryEvent. Fixes GH-581
            userInfo["release"] = options.releaseName
            userInfo["dist"] = options.dist

            // Crashes don't use the attributes field, we remove them to avoid uploading
            // them unnecessarily.
            userInfo.removeValue(forKey: "attributes")

            KSCrash.shared.userInfo = userInfo

            outerScope.add(self.scopeObserver)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(currentLocaleDidChange(_:)),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )

        if #available(macOS 12.0, *) {
            updateLowPowerModeContext(ProcessInfo.processInfo)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(powerStateDidChange(_:)),
                name: .NSProcessInfoPowerStateDidChange,
                object: nil
            )
        }
    }

    @objc private func currentLocaleDidChange(_ notification: Notification) {
        SentrySDKInternal.currentHub().configureScope { scope in
            var device = (scope.contextDictionary[SENTRY_CONTEXT_DEVICE_KEY] as? [String: Any]) ?? [:]
            device["locale"] = Locale.autoupdatingCurrent.identifier

            scope.setContext(value: device, key: SENTRY_CONTEXT_DEVICE_KEY)
        }
    }

    @objc @available(macOS 12.0, *)
    private func powerStateDidChange(_ notification: Notification) {
        let processInfo = (notification.object as? ProcessInfo) ?? ProcessInfo.processInfo

        updateLowPowerModeContext(processInfo)
    }

    @available(macOS 12.0, *)
    private func updateLowPowerModeContext(_ processInfo: ProcessInfo) {
        SentrySDKInternal.currentHub().configureScope { scope in
            var device = (scope.contextDictionary[SENTRY_CONTEXT_DEVICE_KEY] as? [String: Any]) ?? [:]
            device["low_power_mode"] = processInfo.isLowPowerModeEnabled

            scope.setContext(value: device, key: SENTRY_CONTEXT_DEVICE_KEY)
        }
    }
}
