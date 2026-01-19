@_implementationOnly import _SentryPrivate
import Foundation

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
import UIKit
#endif

// MARK: - C Callback Function

/// Global function to finish and save transaction when a crash occurs.
/// This function is called from C crash reporting code.
@_cdecl("sentry_finishAndSaveTransaction")
public func sentry_finishAndSaveTransaction() {
    let scope = SentrySDKInternal.currentHub().scope as Scope
    guard let span = scope.getCastedInternalSpan() else {
        SentrySDKLog.debug("No span found in current scope, skipping transaction finish and save")
        return
    }
    span.tracer?.finishForCrash()
}

// MARK: - Dependency Provider

/// Provides dependencies for `SentryCrashIntegration`.
typealias CrashIntegrationProvider = DispatchQueueWrapperProvider & CrashWrapperProvider & SentryCrashReporterProvider & CrashIntegrationSessionHandlerBuilder

// MARK: - SentryCrashIntegration

final class SentryCrashIntegration<Dependencies: CrashIntegrationProvider>: NSObject, SwiftIntegration {

    private weak var options: Options?
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let crashWrapper: SentryCrashWrapper
    private var sessionHandler: SentryCrashIntegrationSessionHandler?
    private var scopeObserver: SentryCrashScopeObserver?
    private var crashReporter: SentryCrashSwift
    
    private let installationLock = NSRecursiveLock()
    private var installationToken: Int = 0
    private var installation: SentryCrashInstallationReporter?

    // MARK: - Initialization

    // swiftlint:disable function_body_length
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableCrashHandler else {
            SentrySDKLog.debug("Not going to enable \(Self.name) because enableCrashHandler is disabled.")
            return nil
        }

        self.options = options
        self.dispatchQueueWrapper = dependencies.dispatchQueueWrapper
        self.crashWrapper = dependencies.crashWrapper
        self.crashReporter = dependencies.crashReporter

        super.init()

        self.sessionHandler = dependencies.getCrashIntegrationSessionBuilder(options)
        self.scopeObserver = SentryCrashScopeObserver(maxBreadcrumbs: Int(options.maxBreadcrumbs))

        guard self.sessionHandler != nil, self.scopeObserver != nil else {
            SentrySDKLog.warning("Failed to initialize SentryCrashIntegration dependencies")
            return nil
        }

        var enableSigtermReporting = false
        #if !os(watchOS)
        enableSigtermReporting = options.enableSigtermReporting
        #endif

        var enableUncaughtNSExceptionReporting = false
        #if os(macOS)
        if options.enableSwizzling {
            enableUncaughtNSExceptionReporting = options.enableUncaughtNSExceptionReporting
        }
        #endif

        startCrashHandler(
            cacheDirectory: options.cacheDirectoryPath,
            enableSigtermReporting: enableSigtermReporting,
            enableReportingUncaughtExceptions: enableUncaughtNSExceptionReporting,
            enableCppExceptionsV2: options.experimental.enableUnhandledCPPExceptionsV2
        )

        configureScope()

        if options.enablePersistingTracesWhenCrashing {
            configureTracingWhenCrashing()
        }
    }
    // swiftlint:enable function_body_length

    // MARK: - SwiftIntegration

    static var name: String {
        "SentryCrashIntegration"
    }

    func uninstall() {
        installationLock.synchronized {
            if let installation = installation {
                installation.uninstall()
            }
        }

        sentrycrash_setSaveTransaction(nil)

        NotificationCenter.default.removeObserver(
            self,
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
    }

    // MARK: - Crash Handler

    private func startCrashHandler(
        cacheDirectory: String,
        enableSigtermReporting: Bool,
        enableReportingUncaughtExceptions: Bool,
        enableCppExceptionsV2: Bool
    ) {
        installationLock.synchronized {
            withUnsafeMutablePointer(to: &installationToken) { token in
                dispatchQueueWrapper.dispatchOnce(token) {
                    self.initializeCrashHandler(
                        cacheDirectory: cacheDirectory,
                        enableSigtermReporting: enableSigtermReporting,
                        enableReportingUncaughtExceptions: enableReportingUncaughtExceptions,
                        enableCppExceptionsV2: enableCppExceptionsV2
                    )
                }
            }
        }
    }

    private func initializeCrashHandler(
        cacheDirectory: String,
        enableSigtermReporting: Bool,
        enableReportingUncaughtExceptions: Bool,
        enableCppExceptionsV2: Bool
    ) {
        var canSendReports = false

        if installation == nil {
            guard let options = self.options else { 
                SentrySDKLog.debug("No options found, skipping crash handler initialization")
                return 
            }

            let inAppLogic = SentryInAppLogic(inAppIncludes: options.inAppIncludes)

            let installation = SentryCrashInstallationReporter(
                inAppLogic: inAppLogic,
                crashWrapper: self.crashWrapper,
                dispatchQueue: self.dispatchQueueWrapper
            )

            self.installation = installation
            canSendReports = true
        }

        sentrycrashcm_setEnableSigtermReporting(enableSigtermReporting)

        installation?.install(cacheDirectory)

        #if os(macOS)
        if enableReportingUncaughtExceptions {
            SentryUncaughtNSExceptions.configureCrashOnExceptions()
            SentryUncaughtNSExceptions.swizzleNSApplicationReportException()
        }
        #endif

        if enableCppExceptionsV2 {
            SentrySDKLog.debug("Enabling CppExceptionsV2 by swapping cxa_throw.")
            sentrycrashcm_cppexception_enable_swap_cxa_throw()
        }

        // We need to send the crashed event together with the crashed session in the same envelope
        // to have proper statistics in release health. To achieve this we need both synchronously
        // in the hub. The crashed event is converted from a SentryCrashReport to an event in
        // SentryCrashReportSink and then passed to the SDK on a background thread. This process is
        // started with installing this integration. We need to end and delete the previous session
        // before being able to start a new session for the AutoSessionTrackingIntegration. The
        // SentryCrashIntegration is installed before the AutoSessionTrackingIntegration so there is
        // no guarantee if the crashed event is created before or after the
        // AutoSessionTrackingIntegration. By ending the previous session and storing it as crashed
        // in here we have the guarantee once the crashed event is sent to the hub it is already
        // there and the AutoSessionTrackingIntegration can work properly.
        //
        // This is a pragmatic and not the most optimal place for this logic.
        self.sessionHandler?.endCurrentSessionIfRequired()

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

#if SENTRY_TEST || SENTRY_TEST_CI
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
        SentrySDKInternal.currentHub().configureScope { [weak self] outerScope in
            guard let self = self, let options = self.options else { return }

            var userInfo = outerScope.serialize()

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

            crashReporter.userInfo = userInfo

            if let scopeObserver = self.scopeObserver {
                outerScope.add(scopeObserver)
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(currentLocaleDidChange),
            name: NSLocale.currentLocaleDidChangeNotification,
            object: nil
        )
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

    // MARK: - Tracing Configuration

    private func configureTracingWhenCrashing() {
        sentrycrash_setSaveTransaction(sentry_finishAndSaveTransaction)
    }
}
