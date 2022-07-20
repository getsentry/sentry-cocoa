import Sentry

class TestSentryPermissionsObserver: SentryPermissionsObserver {
    var internalPushPermissionStatus = SentryPermissionStatus.unknown
    var internalLocationPermissionStatus = SentryPermissionStatus.unknown
    var internalMediaLibraryPermissionStatus = SentryPermissionStatus.unknown

    override func startObserving() {
        // noop
    }

    override var pushPermissionStatus: SentryPermissionStatus {
        get {
            return internalPushPermissionStatus
        }
        set {}
    }

    override var locationPermissionStatus: SentryPermissionStatus {
        get {
            return internalLocationPermissionStatus
        }
        set {}
    }

    override var mediaLibraryPermissionStatus: SentryPermissionStatus {
        get {
            return internalMediaLibraryPermissionStatus
        }
        set {}
    }
}
