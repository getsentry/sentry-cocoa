#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import _SentryPrivate
import Foundation
import SentryTestUtilsObjC

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
    /// Resets extensive global SDK state to ensure test isolation.
    ///
    /// - CAUTION: Use sparingly and prefer resetting only the specific state needed for your test case.
    /// Indiscriminate use can mask side effects and make tests fragile. When possible, isolate
    /// tests by mocking dependencies or using local state instead of relying on this global reset.
    ///
    /// - Requires: Must be called on the main thread. Calling on a background thread could interfere
    /// with other currently running tests, making them flaky.
    static func clearTestState() {
        assert(Thread.isMainThread, "You must call clearTestState on the main thread.")
        
        SentrySDK.close()
        wrapper_setCurrentHub(nil)
        SentrySDKInternal.lastRunStatusCalled = false
        SentrySDKInternal.fatalDetected = false
        SentrySDKInternal.startInvocations = 0
        SentrySDKInternal.setDetectedStartUpCrash(false)
        SentrySDK.setStart(with: nil)
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = false
        SentryDependencyContainer.sharedInstance().networkTracker.disable()

        SentrySDKLog.setDefaultTestLogConfiguration()

        #if os(iOS) || os(tvOS) || os(visionOS)

        setenv("ActivePrewarm", "0", 1)
        SentryAppStartTracker.load()
        SentryDependencyContainer.sharedInstance().uiViewControllerPerformanceTracker.alwaysWaitForFullDisplay = false
        SentryDependencyContainer.sharedInstance().swizzleWrapper.removeAllCallbacks()
        SentryDependencyContainer.sharedInstance().fileManager?.clearDiskState()

        #endif // os(iOS) || os(tvOS) || os(visionOS)
        
        SentryDependencyContainer.reset()
        wrapper_clearPerformanceTracker()

#if os(iOS) || os(tvOS) || os(visionOS)
        SentryAppStartMeasurementProvider.reset()
#endif // os(iOS) || os(tvOS) || os(visionOS)

#if os(iOS) || os(macOS)
        wrapper_resetProfilingState()
#endif // os(iOS) || os(macOS)

        #if os(iOS) || os(tvOS) || os(visionOS)
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable = nil
        SentrySDKInternal.setAppStartMeasurement(nil)
        #endif // os(iOS) || os(tvOS) || os(visionOS)

        sentrycrash_scopesync_reset()

        #if SENTRY_TEST || SENTRY_TEST_CI
        SentrySdkPackage.resetPackageManager()
        SentryExtraPackages.clear()
        #endif
    }
}
