@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
import UIKit
private typealias CrossPlatformApplication = UIApplication
#elseif os(macOS)
import AppKit
private typealias CrossPlatformApplication = NSApplication
#endif

#if ((os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT) || os(macOS)

protocol NotificationCenterProvider {
    var notificationCenterWrapper: SentryNSNotificationCenterWrapper { get }
}

final class FlushLogsIntegration<Dependencies: NotificationCenterProvider>: NSObject, SwiftIntegration {
    
    private let notificationCenter: SentryNSNotificationCenterWrapper
    
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableLogs else {
            return nil
        }
        
        self.notificationCenter = dependencies.notificationCenterWrapper
        
        super.init()
        
        notificationCenter.addObserver(
            self,
            selector: #selector(willResignActive),
            name: CrossPlatformApplication.willResignActiveNotification,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(willTerminate),
            name: CrossPlatformApplication.willTerminateNotification,
            object: nil
        )
    }
    
    func uninstall() {
        notificationCenter.removeObserver(
            self,
            name: CrossPlatformApplication.willResignActiveNotification,
            object: nil
        )
        
        notificationCenter.removeObserver(
            self,
            name: CrossPlatformApplication.willTerminateNotification,
            object: nil
        )
    }
    
    deinit {
        uninstall()
    }
    
    @objc private func willResignActive() {
        guard let client = SentrySDKInternal.currentHub().getClient() else {
            SentrySDKLog.debug("No need to flush logs on `willResignActive` because there is no client.")
            return
        }
        client.captureLogs()
    }
    
    @objc private func willTerminate() {
        guard let client = SentrySDKInternal.currentHub().getClient() else {
            SentrySDKLog.debug("No need to flush logs on `willTerminate` because there is no client.")
            return
        }
        client.captureLogs()
    }
    
    static var name: String {
        "FlushLogsIntegration"
    }
}

#endif
