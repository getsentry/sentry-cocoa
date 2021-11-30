import Foundation

func clearTestState() {
    SentrySDK.close()
    SentrySDK.setCurrentHub(nil)
    SentrySDK.crashedLastRunCalled = false
    
    PrivateSentrySDKOnly.onAppStartMeasurementAvailable = nil
    PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = false
    SentrySDK.setAppStartMeasurement(nil)
    CurrentDate.setCurrentDateProvider(nil)
    SentryNetworkTracker.sharedInstance.disable()
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    let framesTracker = SentryFramesTracker.sharedInstance()
    framesTracker.stop()
    framesTracker.resetFrames()
    
    let swizzling = SentryUIViewControllerSwizzling(options: Options(), dispatchQueue: SentryDispatchQueueWrapper())
    swizzling.start()
    #endif
}
