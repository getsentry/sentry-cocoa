#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate
import SentryTestUtilsObjC

extension SentrySDKInternal {
    public static var options: Options? {
        guard let object = test_options() else { return nil }
        return requireTestBridgeValue(object)
    }
}
