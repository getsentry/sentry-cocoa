@_implementationOnly import _SentryPrivate
import Foundation
@_implementationOnly import KSCrashRecording

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit
#endif

// MARK: - Dependency Provider

/// Provides dependencies for `KSCrashIntegration`.
typealias KSCrashIntegrationProvider = KSCrashReporterProvider
    & KSCrashIntegrationSessionHandlerBuilder
    & DateProviderProvider
    & FileManagerProvider
    & AppStateManagerProvider

// MARK: - KSCrashIntegration

final class KSCrashIntegration<Dependencies: KSCrashIntegrationProvider>: NSObject, SwiftIntegration {
    private weak var options: Options?

    private var scopeObserver: SentryKSCrashScopeObserver
    private var sessionHandler: SentryKSCrashIntegrationSessionHandler?
    private var crashReporter: SentryCrashReporter
    private var installation: SentryKSCrashInstallationReporter?

    // MARK: - Initialization

    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableCrashHandler else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableCrashHandler is disabled.")
            return nil
        }

        self.options = options
        self.crashReporter = dependencies.kscrashReporter
        self.scopeObserver = SentryKSCrashScopeObserver(maxBreadcrumbs: Int(options.maxBreadcrumbs))

        super.init()

        var enableSigtermReporting = false
        #if !os(watchOS)
        enableSigtermReporting = options.enableSigtermReporting
        #endif

        let enableCppExceptionsV2 = options.experimental.enableUnhandledCPPExceptionsV2

        startCrashHandler(
            cacheDirectory: options.cacheDirectoryPath,
            enableSigtermReporting: enableSigtermReporting,
            enableCppExceptionsV2: enableCppExceptionsV2,
            dependencies: dependencies
        )

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
                name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
                object: nil
            )
        }

        // KSCrash does not support uninstalling monitors after installation.
        // Clear userInfo so sensitive scope data is not retained in memory.
        KSCrash.shared.userInfo = nil
    }

    // MARK: - Crash Handler

    private func startCrashHandler(
        cacheDirectory: String,
        enableSigtermReporting: Bool,
        enableCppExceptionsV2: Bool,
        dependencies: Dependencies
    ) {
        guard let options = self.options else {
            SentrySDKLog.debug("No options found, skipping crash handler initialization")
            return
        }

        let inAppLogic = SentryInAppLogic(inAppIncludes: options.inAppIncludes)
        self.installation = SentryKSCrashInstallationReporter(inAppLogic: inAppLogic)

        let persistTracesOnCrash = options.enablePersistingTracesWhenCrashing
        let config = SentryKSCrashConfigurationFactory.configuration(
            withInstallPath: cacheDirectory,
            monitors: .productionSafeMinimal,
            enableSigTermMonitoring: enableSigtermReporting,
            enableSwapCxaThrow: enableCppExceptionsV2,
            persistTracesOnCrash: persistTracesOnCrash)

        try? installation?.install(with: config)

        // The crash reporter has loaded its state from disk. Set these flags so
        // SentrySDK.lastRunStatus returns a definitive answer.
        SentrySDKInternal.crashReporterInstalled = true
        if SentryDependencyContainer.sharedInstance().crashWrapper.crashedLastLaunch {
            SentrySDKInternal.fatalDetected = true
        }

        self.sessionHandler = dependencies.getKSCrashIntegrationSessionHandler(options)
        sessionHandler?.endCurrentSessionIfRequired()

        installation?.sendAllReports(completion: nil)
    }

    // MARK: - Scope Configuration

    private func configureScope() {
        SentrySDKInternal.currentHub().configureScope { [weak self] outerScope in
            guard let self = self, let options = self.options else { return }

            var userInfo = outerScope.serialize()

            // KSCrashReportSink needs the release name and dist of the SentryOptions
            // in the UserInfo so it can map them to the event.
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
