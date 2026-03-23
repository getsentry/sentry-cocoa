import Foundation
@_spi(Private) @testable import Sentry

/**
 * This is a test wrapper around SentryCrashWrapper for testing purposes.
 */
class TestSentryCrashWrapper: SentryCrashWrapper {

    // MARK: - Test Properties

    var internalCrashedLastLaunch = false
    var internalDurationFromCrashStateInitToLastCrash: TimeInterval = 0
    var internalActiveDurationSinceLastCrash: TimeInterval = 0
    var internalIsBeingTraced = false
    var internalIsSimulatorBuild = false
    var internalIsApplicationInForeground = true
    var internalFreeMemorySize: UInt64 = 0
    var internalAppMemorySize: UInt64 = 0
    var binaryCacheStarted = false
    var binaryCacheStopped = false
    var enrichScopeCalled = false

    // MARK: - Initialization

    init(processInfoWrapper: SentryProcessInfoSource) {
        // Create a test bridge from the shared container
        let container = SentryDependencyContainer.sharedInstance()
        let bridge = SentryCrashBridge(
            notificationCenterWrapper: container.notificationCenterWrapper,
            dateProvider: container.dateProvider,
            crashReporter: container.crashReporter
        )
        super.init(processInfoWrapper: processInfoWrapper, bridge: bridge)
    }
    
    // MARK: - Overridden Methods
    
    override func startBinaryImageCache() {
        binaryCacheStarted = true
        super.startBinaryImageCache()
    }
    
    override func stopBinaryImageCache() {
        super.stopBinaryImageCache()
        binaryCacheStopped = true
    }
    
    override var crashedLastLaunch: Bool {
        return internalCrashedLastLaunch
    }
    
    override var durationFromCrashStateInitToLastCrash: TimeInterval {
        return internalDurationFromCrashStateInitToLastCrash
    }
    
    override var activeDurationSinceLastCrash: TimeInterval {
        return internalActiveDurationSinceLastCrash
    }
    
    override var isBeingTraced: Bool {
        return internalIsBeingTraced
    }
    
    override var isSimulatorBuild: Bool {
        return internalIsSimulatorBuild
    }
    
    override var isApplicationInForeground: Bool {
        return internalIsApplicationInForeground
    }

    override var freeMemorySize: UInt64 {
        return internalFreeMemorySize
    }
    
    override var appMemorySize: UInt64 {
        return internalAppMemorySize
    }
    
    override func enrichScope(_ scope: Scope) {
        enrichScopeCalled = true
        super.enrichScope(scope)
    }
}
