import Foundation

func clearTestState() {
    SentrySDK.close()
    SentrySDK.setCurrentHub(nil)
    SentrySDK.setAppStartMeasurement(nil)
    CurrentDate.setCurrentDateProvider(nil)
    SentryNetworkTracker.sharedInstance.disable()
}
