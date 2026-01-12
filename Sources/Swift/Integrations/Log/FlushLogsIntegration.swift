@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT
import UIKit
private typealias CrossPlatformApplication = UIApplication
#elseif os(macOS)
import AppKit
private typealias CrossPlatformApplication = NSApplication
#endif

#if ((os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UIKIT) || os(macOS)

protocol NotificationCenterProvider {
    var notificationCenterWrapper: SentryNSNotificationCenterWrapper { get }
}

final class FlushLogsIntegration<Dependencies: NotificationCenterProvider>: NSObject, SwiftIntegration {
    
    private let notificationCenter: SentryNSNotificationCenterWrapper
    private let options: Options
    
    init?(with options: Options, dependencies: Dependencies) {
        guard options.enableLogs else {
            return nil
        }
        
        self.notificationCenter = dependencies.notificationCenterWrapper
        self.options = options
        
        super.init()
        
        createTelemetryBufferFolderIfNeeded()
        
        setDetectedTerminationFilePath()
        recoverDetectedTerminationIfNeeded()
        
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
    
    // MARK: - Telemetry Buffer Setup
    
    private func createTelemetryBufferFolderIfNeeded() {
        let telemetryBufferFolder = getTelemetryBufferFolderURL()
        let fileManager = FileManager.default
        
        guard !fileManager.fileExists(atPath: telemetryBufferFolder.path) else {
            return
        }
        do {
            try fileManager.createDirectory(atPath: telemetryBufferFolder.path, withIntermediateDirectories: true, attributes: nil)
        } catch {
            SentrySDKLog.warning("FlushLogsIntegration: Failed to create telemetry buffer folder at \(telemetryBufferFolder): \(error)")
        }
    }
    
    private func setDetectedTerminationFilePath() {
        let telemetryBufferFolder = getTelemetryBufferFolderURL()
        let detectedTerminationFilePath = getDetectedTerminationFileURL(folder: telemetryBufferFolder).path
        detectedTerminationFilePath.withCString { cPath in
            sentryLogSync_setPath(cPath)
        }
    }
    
    private func getTelemetryBufferFolderURL() -> URL {
        // Path: {cacheDirectoryPath}/io.sentry/{dsnHash}/telemetry-buffer
        
        var url = URL(fileURLWithPath: options.cacheDirectoryPath)
        url.appendPathComponent("io.sentry")
        let dsnHash = options.parsedDsn?.getHash() ?? ""
        url.appendPathComponent(dsnHash)
        url.appendPathComponent("telemetry-buffer")
        return url
    }
    
    private func getDetectedTerminationFileURL(folder: URL) -> URL {
        return folder.appendingPathComponent("detected-termination")
    }
    
    private func recoverDetectedTerminationIfNeeded() {
        let telemetryBufferFolder = getTelemetryBufferFolderURL()
        let detectedTerminationFile = getDetectedTerminationFileURL(folder: telemetryBufferFolder)
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: detectedTerminationFile.path) else {
            return
        }
        
        defer {
            do {
                try fileManager.removeItem(at: detectedTerminationFile)
                SentrySDKLog.debug("FlushLogsIntegration: Crash logs file deleted.")
            } catch {
                SentrySDKLog.warning("FlushLogsIntegration: Failed to delete crash logs file: \(error)")
            }
        }
        
        do {
            let data = try Data(contentsOf: detectedTerminationFile)
            
            // Parse JSON to count items
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [Any] else {
                SentrySDKLog.warning("FlushLogsIntegration: Invalid/Corruptes crash logs file format.")
                return
            }
            
            let itemCount = items.count
            guard itemCount > 0 else {
                return
            }
            
            SentrySDKLog.debug("FlushLogsIntegration: Recovering \(itemCount) crash logs.")
            
            // TEPM: Send the logs through the client (which conforms to SentryLogBatcherDelegate)
            guard let client = SentrySDKInternal.currentHub().getClient() as? SentryLogBatcherDelegate else {
                SentrySDKLog.warning("FlushLogsIntegration: No client available to send recovered logs.")
                return
            }
            
            client.capture(logsData: data as NSData, count: NSNumber(value: itemCount))
            
            SentrySDKLog.debug("FlushLogsIntegration: Crash logs recovered and sent as envelope.")
        } catch {
            SentrySDKLog.warning("FlushLogsIntegration: Failed to recover crash logs: \(error)")
        }
    }
    
    static var name: String {
        "FlushLogsIntegration"
    }
}

#endif
