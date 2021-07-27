import Foundation

func clearTestState() {
    SentrySDK.close()
    SentrySDK.setCurrentHub(nil)
    PrivateSentrySDKOnly.onAppStartMeasurementAvailable = nil
    SentrySDK.setAppStartMeasurement(nil)
    CurrentDate.setCurrentDateProvider(nil)
    SentryNetworkTracker.sharedInstance.disable()
}
