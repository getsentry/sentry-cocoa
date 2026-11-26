#if SWIFT_PACKAGE
#if !SDK_V10
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate
import SentryTestUtilsObjC

extension SentryTracer {
    @_spi(Private) public var measurements: [String: SentryMeasurementValue] {
        requireTestBridgeValue(test_measurements())
    }
}
#endif
