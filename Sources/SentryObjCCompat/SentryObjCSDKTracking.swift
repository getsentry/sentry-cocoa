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
        guard PrivateSentrySDKOnly.getSdkName() == baseSDKName else {
            return
        }

        PrivateSentrySDKOnly.setSdkName(objcSDKName)
        didSetObjCSDKName = true
    }

    static func markClosedThroughObjCWrapper() {
        guard didSetObjCSDKName,
              PrivateSentrySDKOnly.getSdkName() == objcSDKName else {
            return
        }

        PrivateSentrySDKOnly.setSdkName(baseSDKName)
        didSetObjCSDKName = false
    }
}
