import Sentry

class TestSentryPermissionsObserver: SentryPermissionsObserver {
    var internalPushPermissionStatus = SentryPermissionStatus.unknown
    var internalLocationPermissionStatus = SentryPermissionStatus.unknown
    var internalMediaLibraryPermissionStatus = SentryPermissionStatus.unknown
    var internalPhotoLibraryPermissionStatus = SentryPermissionStatus.unknown

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

    override var photoLibraryPermissionStatus: SentryPermissionStatus {
        get {
            return internalPhotoLibraryPermissionStatus
        }
        set {}
    }
}
