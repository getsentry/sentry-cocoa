@_spi(Private) import Sentry
import _SentryPrivate
import SentryTestUtilsObjC

extension SentrySDKInternal {
    public static var options: Options? {
        guard let object = test_options() else { return nil }
        return requireTestBridgeValue(object)
    }
}
