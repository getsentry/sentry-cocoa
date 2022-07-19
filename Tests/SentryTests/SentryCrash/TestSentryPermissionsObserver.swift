import Foundation

class TestSentryPermissionsObserver: SentryPermissionsObserver {
    var internalPushPermissionStatus = SentryPermissionStatus(0)
    var internalLocationPermissionStatus = SentryPermissionStatus(0)

    override func startObserving() {
        // noop
    }

    public func getPushPermissionStatus() -> SentryPermissionStatus {
        return internalPushPermissionStatus
    }

    public func getLocationPermissionStatus() -> SentryPermissionStatus {
        return internalLocationPermissionStatus
    }
}
