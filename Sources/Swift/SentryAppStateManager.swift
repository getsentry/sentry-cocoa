@_implementationOnly import _SentryPrivate

#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
import UIKit
#endif

@_spi(Private) @objc public final class SentryAppStateManager: NSObject {
    
    private let options: Options?
    private let crashWrapper: SentryCrashWrapper
    private let fileManager: SentryFileManager?
#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
    private let _updateAppState: (@escaping (SentryAppState) -> Void) -> Void
    private let _buildCurrentAppState: () -> SentryAppState
    private let helper: SentryDefaultAppStateManager
#endif
    
    init(options: Options?, crashWrapper: SentryCrashWrapper, fileManager: SentryFileManager?, sysctlWrapper: SentrySysctl) {
        self.options = options
        self.crashWrapper = crashWrapper
        self.fileManager = fileManager
#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
        let lock = NSRecursiveLock()
        let buildCurrentAppState = {
            // Is the current process being traced or not? If it is a debugger is attached.
            let isDebugging = crashWrapper.isBeingTraced

            let device = UIDevice.current
            let vendorId = device.identifierForVendor?.uuidString

            return SentryAppState(releaseName: options?.releaseName, osVersion: device.systemVersion, vendorId: vendorId, isDebugging: isDebugging, systemBootTimestamp: sysctlWrapper.systemBootTimestamp)
        }
        _buildCurrentAppState = buildCurrentAppState
        let updateAppState: (@escaping (SentryAppState) -> Void) -> Void = { block in
            lock.synchronized {
                let appState = fileManager?.readAppState()
                if let appState {
                    block(appState)
                    fileManager?.store(appState)
                }
            }
        }
        _updateAppState = updateAppState
        helper = SentryDefaultAppStateManager(storeCurrent: {
            fileManager?.store(buildCurrentAppState())
        }, updateTerminated: {
            updateAppState { $0.wasTerminated = true }
        }, updateSDKNotRunning: {
            updateAppState { $0.isSDKRunning = false }
        }, updateActive: { active in
            updateAppState { $0.isActive = active }
        })
#endif
    }
    
#if (os(iOS) || os(tvOS) || (swift(>=5.9) && os(visionOS))) && !SENTRY_NO_UIKIT
    var startCount: Int {
        helper.startCount
    }
    
    @objc public func start() {
        helper.start()
    }
    @objc public func stop() {
        helper.stop()
    }
    @objc public func stop(withForce force: Bool) {
        helper.stop(withForce: force)
    }
    
    /**
     * Builds the current app state.
     * @discussion The systemBootTimestamp is calculated by taking the current time and subtracting
     * @c NSProcesInfo.systemUptime . @c NSProcesInfo.systemUptime returns the amount of time the system
     * has been awake since the last time it was restarted. This means This is a good enough
     * approximation about the timestamp the system booted.
     */
    @objc public func buildCurrentAppState() -> SentryAppState {
        _buildCurrentAppState()
    }
    
    @objc public func loadPreviousAppState() -> SentryAppState? {
        fileManager?.readPreviousAppState()
    }
    
    func storeCurrentAppState() {
        fileManager?.store(buildCurrentAppState())
    }
    
    @objc public func updateAppState(_ block: @escaping (SentryAppState) -> Void) {
        _updateAppState(block)
    }
#endif
}
