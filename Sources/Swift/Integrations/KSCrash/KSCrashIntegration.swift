@_implementationOnly import _SentryPrivate
import KSCrashRecording

// MARK: - Dependency Provider

/// Provides dependencies for `KSCrashIntegration`.
typealias KSCrashIntegrationProvider = KSCrashReporterProvider & KSCrashIntegrationSessionHandlerBuilder & CrashInstallationReporterBuilder

// MARK: - KSCrashIntegration

final class KSCrashIntegration<Dependencies: KSCrashIntegrationProvider>: NSObject, SwiftIntegration {
    private weak var options: Options?

    private let scopeObserver: SentryKSCrashScopeObserver
    private let crashReporter: SentryCrashReporter
    private let installation: SentryKSCrashInstallationReporter

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
        "CrashIntegration"
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
    private func buildKSCrashConfig(for options: Options) -> KSCrashConfiguration {
        let enableSigtermReporting: Bool
        #if !os(watchOS)
        enableSigtermReporting = options.enableSigtermReporting
        #else
        enableSigtermReporting = false
        #endif

        let config = KSCrashConfiguration()
        config.installPath = options.cacheDirectoryPath
        config.reportStoreConfiguration.reportsPath = (options.cacheDirectoryPath as NSString).appendingPathComponent("Reports")
        config.monitors = .productionSafeMinimal
        config.enableSigTermMonitoring = enableSigtermReporting
        config.enableSwapCxaThrow = options.experimental.enableUnhandledCPPExceptionsV2

        // According to the KSCrash documentation, when using the `-[KSCrashInstallation installWithConfiguration:]
        // installation method, this config field is ignored - instead, we can use
        // `-[KSCrashInstallation setIsWritingReportCallback:] method to install this callback.
        config.isWritingReportCallback = { plan, writer in
            if plan.pointee.crashedDuringExceptionHandling {
                return
            }

            if let json = ScopeJSON.get() {
                writer.pointee.addJSONElement(writer, CrashField.sentrySDKScope.rawValue, json, false)
            }
        }

        if options.enablePersistingTracesWhenCrashing {
            config.willWriteReportCallback = { (plan, _) in
                if plan.pointee.crashedDuringExceptionHandling || plan.pointee.requiresAsyncSafety {
                    return
                }

                guard let span = SentrySDKInternal.currentHub().scope.getCastedInternalSpan() else {
                    SentrySDKLog.debug("No span found in current scope, skipping transaction finish and save")
                    return
                }
                span.tracer?.finishForCrash()
            }
        }

        // Store the effective reports path and app name as static state so the @convention(c)
        // callback can access them without capturing locals. Mirrors the defaults KSCrash applies
        // at install time: installPath + "/Reports" (KSCRS_DEFAULT_REPORTS_FOLDER), appName = CFBundleName.
        SentryCrashAttachmentsStorage.reportsPath = (options.cacheDirectoryPath as NSString).appendingPathComponent("Reports")
        SentryCrashAttachmentsStorage.appName = config.reportStoreConfiguration.appName
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "Unknown"

        config.didWriteReportCallback = { plan, reportID in
            // Double-fault: we're crashing inside the crash handler; do as little as possible.
            guard !plan.pointee.crashedDuringExceptionHandling else { return }

            // Best-effort — mirrors original SentryCrash which always ran these after writing
            // the report, even from signal context. App is already dying; acceptable to risk it.
            guard let base = SentryCrashAttachmentsStorage.basePath else { return }
            // TODO: this is the internal report ID and we can't use this later as a lookup...  see if we can get the report and find the UUID and use that instead?
            let reportIDHex = String(format: "%016llx", UInt64(bitPattern: reportID))
            let dirPath = (base as NSString).appendingPathComponent(reportIDHex)
            try? FileManager.default.createDirectory(atPath: dirPath, withIntermediateDirectories: true)

            SentryCrashAttachmentsStorage.screenshotCallback?(dirPath)
            SentryCrashAttachmentsStorage.viewHierarchyCallback?(dirPath)

            print("WHATS UP WE OUT HERE FR FR")

            // HACK: The report ID provided here isn't in the report - it _is_ in the report path
            // but when the sink sees reports - it only see's the dictionary value...
            // Here, we can't edit the report directly via KSCrash without having to duplicate the report
            // So... using the report ID and knowing the path KSCrash uses to write reports...
            // look it up, deseralize it, edit it, reseralize it, write it to disk.
            // This is brittle - if KSCrash changes their pathing... this is cooked.
            // We should look for a way to better write items to a report post-report writing
            // TODO: This is currently disabled as any report being written by this is being rejected on next launch as it's unable to be json decoded by KSCrash (it is RFC 8259 compliant according to other JSON validators
//            guard
//                let reportsPath = SentryCrashAttachmentsStorage.reportsPath,
//                let appName = SentryCrashAttachmentsStorage.appName
//            else { return }
//
//            let reportPath = (reportsPath as NSString).appendingPathComponent("\(appName)-report-\(reportIDHex).json")
////
//            guard
//                FileManager.default.fileExists(atPath: reportPath),
//                let data = try? Data(contentsOf: URL(fileURLWithPath: reportPath)),
//                var report = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//                let files = try? FileManager.default.contentsOfDirectory(atPath: dirPath),
//                !files.isEmpty
//            else {
//                return
//            }
//
//            let attachments = files.map { "\(dirPath)/\($0)" }
//            report[CrashField.attachments.rawValue] = attachments
////
//            guard
//                let seralized = try? JSONSerialization.data(withJSONObject: report, options: [])
//            else {
//                return
//            }
//
//            do {
//                try seralized.write(to: URL(fileURLWithPath: reportPath))
//            } catch {
//                print("ERROR: \(error)")
//            }
        }

        return config
    }

    private func startCrashHandler(options: Options, dependencies: Dependencies) {
        let attachmentsBasePath = (options.cacheDirectoryPath as NSString)
            .appendingPathComponent("Attachments")
        SentryCrashAttachmentsStorage.basePath = attachmentsBasePath

        let config = buildKSCrashConfig(for: options)

        let logPath = (NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] as NSString)
              .appendingPathComponent("kscrash-debug.log")
        kslog_setLogFilename(logPath, true)

        do {
            try KSCrash.shared.install(with: config)
            KSCrash.shared.reportStore?.sink = KSCrashReportSink(inAppLogic: .init(inAppIncludes: options.inAppIncludes))

//            try installation.install(with: config)
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

        installation.sendAllReports(completion: nil)
    }

    // MARK: - Scope Configuration

    private func configureScope() {
        // We need to make sure to set always the scope to SentryCrash so we have it in
        // case of a crash
        SentrySDKInternal.currentHub().configureScope { [weak self] outerScope in
            guard let self, let options else { return }

            var userInfo = outerScope.serialize()

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
