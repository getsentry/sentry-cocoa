#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate
import Foundation
import SentryTestUtilsObjC
import XCTest

extension SentrySDKInternal {
    @_spi(Private) @nonobjc public static func setStart(with options: Options?) {
        test_setStart(with: options)
    }

    #if SWIFT_PACKAGE
    @_spi(Private) @nonobjc public static func capture(_ envelope: SentryEnvelope) {
        test_captureEnvelope(envelope)
    }

    @_spi(Private) @nonobjc public static func store(_ envelope: SentryEnvelope) {
        test_storeEnvelope(envelope)
    }
    #endif

    public static var options: Options? {
        guard let object = test_options() else { return nil }
        return requireTestBridgeValue(object)
    }
}
