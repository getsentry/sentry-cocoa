#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate
import Foundation
import SentryTestUtilsObjC
import XCTest

#if SWIFT_PACKAGE
extension SentryTracer {
    @_spi(Private) public var measurements: [String: SentryMeasurementValue] {
        requireTestBridgeValue(test_measurements())
    }
}
#endif
