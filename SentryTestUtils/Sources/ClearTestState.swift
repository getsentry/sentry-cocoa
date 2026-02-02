import Foundation
@_spi(Private) @testable import Sentry

public func clearTestState() {
    TestCleanup.clearTestState()
}

public func resetUserDefaults() {
    if let appDomain = Bundle.main.bundleIdentifier {
        UserDefaults.standard.removePersistentDomain(forName: appDomain)
        // Although the Apple docs state this shouldn't be used we need it
        // to avoid race conditions in tests for UserDefaults. Not calling
        // this can lead to flaky tests.
        UserDefaults.standard.synchronize()
    }
}

@objcMembers
class TestCleanup: NSObject {
    static func clearTestState() {
        // You must call clearTestState on the main thread. Calling it on a background thread
        // could interfere with another currently running test, making the tests flaky.
        assert(Thread.isMainThread, "You must call clearTestState on the main thread.")
        
        SentrySDK.close()
        SentrySDKInternal.setCurrentHub(nil)
        SentrySDKInternal.crashedLastRunCalled = false
        SentrySDKInternal.startInvocations = 0
        SentrySDKInternal.setDetectedStartUpCrash(false)
        SentrySDK.setStart(with: nil)
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = false
        SentryNetworkTracker.sharedInstance.disable()

        SentrySDKLog.setDefaultTestLogConfiguration()

        #if os(iOS) || os(tvOS)

        setenv("ActivePrewarm", "0", 1)
        SentryAppStartTracker.load()
        SentryDependencyContainer.sharedInstance().uiViewControllerPerformanceTracker.alwaysWaitForFullDisplay = false
        SentryDependencyContainer.sharedInstance().swizzleWrapper.removeAllCallbacks()
        SentryDependencyContainer.sharedInstance().fileManager?.clearDiskState()
        
        #endif // os(iOS) || os(tvOS)
        
        SentryDependencyContainer.reset()
        SentryPerformanceTracker.shared.clear()

        SentryTracer.resetAppStartMeasurementRead()

#if os(iOS) || os(macOS)
        _sentry_threadUnsafe_traceProfileTimeoutTimer = nil
        SentryTraceProfiler.getCurrentProfiler()?.stop(for: SentryProfilerTruncationReason.normal)
        SentryTraceProfiler.resetConcurrencyTracking()
        removeAppLaunchProfilingConfigFile()
        sentry_stopAndDiscardLaunchProfileTracer(nil)

        if SentryContinuousProfiler.isCurrentlyProfiling() {
            SentryContinuousProfiler.stopTimerAndCleanup()
        }
#endif // os(iOS) || os(macOS)

        #if os(iOS) || os(tvOS)
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable = nil
        SentrySDKInternal.setAppStartMeasurement(nil)
        #endif // os(iOS) || os(tvOS)

        sentrycrash_scopesync_reset()

        #if SENTRY_TEST || SENTRY_TEST_CI
        SentrySdkPackage.resetPackageManager()
        SentryExtraPackages.clear()
        #endif
    }
}
