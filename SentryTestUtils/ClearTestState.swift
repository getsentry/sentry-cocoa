import Foundation
import Sentry

public func clearTestState() {
    TestCleanup.clearTestState()
}

@objcMembers
class TestCleanup: NSObject {
    static func clearTestState() {
        SentrySDK.close()
        SentrySDK.setCurrentHub(nil)
        SentrySDK.crashedLastRunCalled = false
        SentrySDK.startInvocations = 0
        PrivateSentrySDKOnly.onAppStartMeasurementAvailable = nil
        PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = false
        SentrySDK.setAppStartMeasurement(nil)
        CurrentDate.setCurrentDateProvider(nil)
        SentryNetworkTracker.sharedInstance.disable()
        
        SentryLog.configure(true, diagnosticLevel: .debug)

        #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
        let framesTracker = SentryFramesTracker.sharedInstance()
        framesTracker.stop()
        framesTracker.resetFrames()

        setenv("ActivePrewarm", "0", 1)
        SentryAppStartTracker.load()
        SentryUIViewControllerPerformanceTracker.shared.enableWaitForFullDisplay = false
        #endif

        SentryDependencyContainer.reset()
        Dynamic(SentryGlobalEventProcessor.shared()).removeAllProcessors()
        SentryPerformanceTracker.shared.clear()
        SentrySwizzleWrapper.sharedInstance.removeAllCallbacks()

        SentryTracer.resetAppStartMeasurementRead()

#if os(iOS) || os(macOS) || targetEnvironment(macCatalyst)
        SentryTracer.resetConcurrencyTracking()
#endif
    }
}
