import Foundation
import Sentry

public func clearTestState() {
    TestCleanup.clearTestState()
}

@objcMembers
class TestCleanup: NSObject {
    static func clearTestState() {
        // You must call clearTestState on the main thread. Calling it on a background thread
        // could interfere with another currently running test, making the tests flaky.
        assert(Thread.isMainThread, "You must call clearTestState on the main thread.")
        
        SentrySDK.close()
        SentrySDK.setCurrentHub(nil)
        SentrySDK.crashedLastRunCalled = false
        SentrySDK.startInvocations = 0
        SentrySDK.setDetectedStartUpCrash(false)
        SentrySDK.setStart(nil)
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = false
        SentryNetworkTracker.sharedInstance.disable()
        
        SentryLog.setTestDefaultLogLevel()

        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

        setenv("ActivePrewarm", "0", 1)
        SentryAppStartTracker.load()
        SentryUIViewControllerPerformanceTracker.shared.enableWaitForFullDisplay = false
        SentryDependencyContainer.sharedInstance().swizzleWrapper.removeAllCallbacks()
        SentryDependencyContainer.sharedInstance().fileManager.clearDiskState()
        
        #endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        
        SentryDependencyContainer.reset()
        Dynamic(SentryGlobalEventProcessor.shared()).removeAllProcessors()
        SentryPerformanceTracker.shared.clear()

        SentryTracer.resetAppStartMeasurementRead()

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        _sentry_threadUnsafe_traceProfileTimeoutTimer = nil
        SentryTraceProfiler.getCurrentProfiler()?.stop(for: SentryProfilerTruncationReason.normal)
        SentryTraceProfiler.resetConcurrencyTracking()
        SentryContinuousProfiler.stop()
        removeAppLaunchProfilingConfigFile()
        sentry_stopAndDiscardLaunchProfileTracer()
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable = nil
        SentrySDK.setAppStartMeasurement(nil)
        #endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)

        sentrycrash_scopesync_reset()
    }
}
