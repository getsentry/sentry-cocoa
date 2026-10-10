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
extension Scope {
    @_spi(Private) public var propagationContext: SentryPropagationContext {
        get { requireTestBridgeValue(test_propagationContext()) }
        set { test_setPropagationContext(newValue) }
    }
}
#endif
