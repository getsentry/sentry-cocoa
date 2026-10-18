#if SWIFT_PACKAGE
internal import SentrySwift
#else
internal import Sentry
#endif

enum SentryObjCSDKTracking {
    private static let baseSDKName = "sentry.cocoa"
    static let objcSDKName = "sentry.cocoa.objc"
    private static var didSetObjCSDKName = false

    static func markStartedThroughObjCWrapper() {
        guard SentrySDK.internal.sdk.name == baseSDKName else {
            return
        }

        SentrySDK.internal.sdk.name = objcSDKName
        didSetObjCSDKName = true
    }

    static func markClosedThroughObjCWrapper() {
        guard didSetObjCSDKName,
              SentrySDK.internal.sdk.name == objcSDKName else {
            return
        }

        SentrySDK.internal.sdk.name = baseSDKName
        didSetObjCSDKName = false
    }
}
