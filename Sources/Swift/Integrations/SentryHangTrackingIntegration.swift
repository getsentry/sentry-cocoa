// swiftlint:disable missing_docs
@_implementationOnly import _SentryPrivate
import Foundation
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
import UIKit
#endif

typealias HangTrackingIntegrationScope = DispatchQueueWrapperProvider & CrashWrapperProvider & ExtensionDetectorProvider & DebugImageProvider & ThreadInspectorProvider & FileManagerProvider & ANRTrackerBuilder

@_spi(Private) @objc public final class SentryHangTrackerIntegrationObjC: NSObject, SwiftIntegration {
    
    private let integration: SentryHangTrackingIntegration<SentryDependencyContainer>

    init?(with options: Options, dependencies: SentryDependencyContainer) {
        guard let integration = SentryHangTrackingIntegration(with: options, dependencies: dependencies) else {
            return nil
        }
        self.integration = integration
    }
    
    @objc public func pauseAppHangTracking() {
        integration.pauseAppHangTracking()
    }
    
    @objc public func resumeAppHangTracking() {
        integration.resumeAppHangTracking()
    }

    static var name: String {
        SentryHangTrackingIntegration<SentryDependencyContainer>.name
    }

    public func uninstall() {
        integration.uninstall()
    }
}

final class SentryHangTrackingIntegration<Dependencies: HangTrackingIntegrationScope>: NSObject, SwiftIntegration, SentryANRTrackerDelegate {

    let tracker: SentryANRTracker
    private let options: Options
    private let fileManager: SentryFileManager
    private let dispatchQueueWrapper: SentryDispatchQueueWrapper
    private let crashWrapper: SentryCrashWrapper
    private let debugImageProvider: SentryDebugImageProvider
    private let threadInspector: SentryThreadInspector
    private var reportAppHangs: Bool = true
    private let reportAppHangsLock = NSRecursiveLock()
    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
    let enableReportNonFullyBlockingAppHangs: Bool
    #endif
    let sentryANRMechanismDataAppHangDuration = "app_hang_duration"

    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableAppHangTracking && options.appHangTimeoutInterval > 0 else {
            return nil
        }
        guard !dependencies.crashWrapper.isBeingTraced else {
            return nil
        }
        // Extension detection
        if let identifier = dependencies.extensionDetector.getExtensionPointIdentifier(), identifier.isDisabledExtensionPointIdentifier {
            SentrySDKLog.debug("Not enabling app hang tracking for extension: \(identifier)")
            return nil
        }

        tracker = dependencies.getANRTracker(options.appHangTimeoutInterval)
        guard let fileManager = dependencies.fileManager else {
            SentrySDKLog.fatal("File manager is not available")
            return nil
        }
        self.fileManager = fileManager
        self.dispatchQueueWrapper = dependencies.dispatchQueueWrapper
        self.crashWrapper = dependencies.crashWrapper
        self.debugImageProvider = dependencies.debugImageProvider
        self.threadInspector = dependencies.threadInspector
        self.options = options
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
        enableReportNonFullyBlockingAppHangs = options.enableReportNonFullyBlockingAppHangs
        #endif
        super.init()
        
        tracker.add(listener: self)

        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
        captureStoredAppHangEvent()
        #endif
    }
    
    static var name: String {
        "SentryANRTrackingIntegration"
    }

    func pauseAppHangTracking() {
        reportAppHangsSafe = false
    }

    func resumeAppHangTracking() {
        reportAppHangsSafe = true
    }

    public func uninstall() {
        tracker.remove(listener: self)
    }
    
    var reportAppHangsSafe: Bool {
        get {
            reportAppHangsLock.synchronized {
                reportAppHangs
            }
        }
        set {
            reportAppHangsLock.synchronized {
                reportAppHangs = newValue
            }
        }
    }

    deinit {
        uninstall()
    }

    public func anrDetected(type: SentryANRType) {
        guard reportAppHangsSafe else {
            SentrySDKLog.debug("AppHangTracking paused. Ignoring reported app hang.")
            return
        }
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
        guard type != .nonFullyBlocking || enableReportNonFullyBlockingAppHangs else {
            SentrySDKLog.debug("Ignoring non fully blocking app hang.")
            return
        }
        guard SentryDependencyContainer.sharedInstance().threadsafeApplication.applicationState == .active else {
            return
        }
        #endif

        let threads = threadInspector.getCurrentThreadsWithStackTrace()
        guard !threads.isEmpty else {
            SentrySDKLog.warning("Getting current thread returned an empty list. Can't create AppHang event without a stacktrace.")
            return
        }
        let durationMs = Int(options.appHangTimeoutInterval * 1_000)
        let appHangDurationInfo = "at least \(durationMs) ms"
        let message = "App hanging for \(appHangDurationInfo)."
        let event = Event(level: .error)

        let exceptionType = SentryAppHangTypeMapper.getExceptionType(anrType: type)
        let sentryException = Exception(value: message, type: exceptionType)
        let mechanism = Mechanism(type: "AppHang")
        sentryException.mechanism = mechanism
        sentryException.stacktrace = threads[0].stacktrace
        sentryException.stacktrace?.snapshot = true
        for (idx, thread) in threads.enumerated() { thread.current = NSNumber(value: (idx == 0)) }
        event.exceptions = [sentryException]
        event.threads = threads

        event.debugMeta = debugImageProvider.getDebugImagesFromCacheForThreads(threads: threads)

        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
        mechanism.data = [sentryANRMechanismDataAppHangDuration: appHangDurationInfo]
        let scope = SentrySDKInternal.currentHub().scope
        scope.applyTo(event: event, maxBreadcrumbs: options.maxBreadcrumbs)
        apply(options: SentrySDK.startOption, toEvent: event)
        fileManager.storeAppHang(event)
        #else
        SentrySDK.capture(event: event)
        #endif
    }

    func apply(options: Options?, toEvent event: Event) {
        guard let options = options else { return }
        event.releaseName = options.releaseName
        if event.dist == nil, let dist = options.dist {
            event.dist = dist
        }
        if event.environment == nil {
            event.environment = options.environment
        }
    }

    public func anrStopped(result: SentryANRStoppedResult?) {
        #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
        guard let result else {
            SentrySDKLog.warning("ANR stopped for V2 but result was nil.")
            return
        }
        guard let event = fileManager.readAppHangEvent() else {
            SentrySDKLog.warning("AppHang stopped but stored app hang event was nil.")
            return
        }
        fileManager.deleteAppHangEvent()
        let appHangDurationInfo = String(format: "between %.1f and %.1f seconds", result.minDuration, result.maxDuration)
        let errorMessage = "App hanging \(appHangDurationInfo)."
        event.exceptions?.first?.value = errorMessage
        guard var mechanismData = event.exceptions?.first?.mechanism?.data else {
            SentrySDKLog.warning("Mechanism data of the stored app hang event was nil... dropping event.")
            return
        }
        mechanismData.removeValue(forKey: sentryANRMechanismDataAppHangDuration)
        event.exceptions?.first?.mechanism?.data = mechanismData
        SentrySDK.capture(event: event, scope: Scope())
        #endif
    }

    #if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
    private func captureStoredAppHangEvent() {
        dispatchQueueWrapper.dispatchAsync { [weak self] in
            guard let self else { return }
            guard let event = fileManager.readAppHangEvent() else { return }
            fileManager.deleteAppHangEvent()
            if crashWrapper.crashedLastLaunch {
                SentrySDK.capture(event: event, scope: Scope())
            } else {
                if event.exceptions?.count != 1 {
                    SentrySDKLog.warning("The stored app hang event is expected to have exactly one exception, so we don't capture it.")
                    return
                }
                event.level = .fatal
                let exception = event.exceptions?.first
                exception?.mechanism?.handled = false
                if let exceptionType = exception?.type {
                    let fatalExceptionType = SentryAppHangTypeMapper.getFatalExceptionType(nonFatalErrorType: exceptionType)
                    event.exceptions?.first?.type = fatalExceptionType
                }
                var mechanismData = exception?.mechanism?.data ?? [:]
                let appHangDurationInfo = mechanismData[sentryANRMechanismDataAppHangDuration] as? String
                mechanismData.removeValue(forKey: sentryANRMechanismDataAppHangDuration)
                event.exceptions?.first?.mechanism?.data = mechanismData
                let exceptionValue = "The user or the OS watchdog terminated your app while it blocked the main thread for \(appHangDurationInfo ?? "?")."
                event.exceptions?.first?.value = exceptionValue
                SentrySDKInternal.captureFatalAppHang(event)
            }
        }
    }
    #endif
}
// swiftlint:enable missing_docs
