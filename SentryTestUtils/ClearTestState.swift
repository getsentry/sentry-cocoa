import Foundation
import Sentry

public func clearTestState() {
    TestCleanup.clearTestState()
}

public func setTestDefaultLogLevel() {
    SentryLog.configure(true, diagnosticLevel: .debug)
}

@objcMembers
class TestCleanup: NSObject {
    static func clearTestState() {
        SentrySDK.close()
        SentrySDK.setCurrentHub(nil)
        SentrySDK.crashedLastRunCalled = false
        SentrySDK.startInvocations = 0
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = false
        SentryNetworkTracker.sharedInstance.disable()
        
        setTestDefaultLogLevel()

        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        let framesTracker = SentryDependencyContainer.sharedInstance().framesTracker
        framesTracker.stop()
        framesTracker.resetFrames()

        setenv("ActivePrewarm", "0", 1)
        SentryAppStartTracker.load()
        SentryUIViewControllerPerformanceTracker.shared.enableWaitForFullDisplay = false
        SentrySwizzleWrapper.sharedInstance.removeAllCallbacks()
        #endif

        SentryDependencyContainer.reset()
        Dynamic(SentryGlobalEventProcessor.shared()).removeAllProcessors()
        SentryPerformanceTracker.shared.clear()

        SentryTracer.resetAppStartMeasurementRead()

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        SentryProfiler.getCurrent().stop(for: .normal)
        SentryTracer.resetConcurrencyTracking()
#endif // os(iOS) || os(macOS) || targetEnvironment(macCatalyst)

        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable = nil
        SentrySDK.setAppStartMeasurement(nil)
        #endif // os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    }
}
