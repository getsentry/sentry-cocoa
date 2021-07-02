import Foundation

func clearTestState() {
    SentrySDK.close()
    SentrySDK.setCurrentHub(nil)
    CurrentDate.setCurrentDateProvider(nil)
}
