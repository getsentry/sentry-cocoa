import Foundation
import Sentry

func clearTestState() {
    SentrySDK.close()
    SentrySDK.setCurrentHub(nil)
    SentrySDK.crashedLastRunCalled = false
    SentrySDK.startInvocations = 0
    
    PrivateSentrySDKOnly.onAppStartMeasurementAvailable = nil
    PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = false
    SentrySDK.setAppStartMeasurement(nil)
    CurrentDate.setCurrentDateProvider(nil)
    SentryNetworkTracker.sharedInstance.disable()
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    let framesTracker = SentryFramesTracker.sharedInstance()
    framesTracker.stop()
    framesTracker.resetFrames()
    
    setenv("ActivePrewarm", "0", 1)
    SentryAppStartTracker.load()
    #endif
    
    SentryDependencyContainer.reset()
    Dynamic(SentryGlobalEventProcessor.shared()).removeAllProcessors()
    SentrySwizzleWrapper.sharedInstance.removeAllCallbacks()
    
    SentryNSDataTracker.sharedInstance.disable()
}
