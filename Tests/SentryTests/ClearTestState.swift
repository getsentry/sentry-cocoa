import Foundation

func clearTestState() {
    SentrySDK.close()
    SentrySDK.setCurrentHub(nil)
    PrivateSentrySDKOnly.onAppStartMeasurementAvailable = nil
    PrivateSentrySDKOnly.appStartMeasurementHybridSDKMode = false
    SentrySDK.setAppStartMeasurement(nil)
    CurrentDate.setCurrentDateProvider(nil)
    SentryNetworkTracker.sharedInstance.disable()
    
    #if os(iOS) || os(tvOS) || targetEnvironment(macCatalyst)
    let framesTracker = SentryFramesTracker.sharedInstance()
    framesTracker.stop()
    framesTracker.resetFrames()
    #endif
}
