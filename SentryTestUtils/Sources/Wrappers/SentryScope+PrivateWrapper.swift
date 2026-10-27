#if SWIFT_PACKAGE
#if !SDK_V10
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate
import SentryTestUtilsObjC

extension Scope {
    @_spi(Private) public var propagationContext: SentryPropagationContext {
        get { requireTestBridgeValue(test_propagationContext()) }
        set { test_setPropagationContext(newValue) }
    }
}
#endif
