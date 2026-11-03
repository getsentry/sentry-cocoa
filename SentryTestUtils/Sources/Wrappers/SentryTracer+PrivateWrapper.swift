#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
import _SentryPrivate
import SentryTestUtilsObjC

extension SentryTracer {
    @_spi(Private) public var measurements: [String: SentryMeasurementValue] {
        requireTestBridgeValue(test_measurements())
    }
}
#endif
