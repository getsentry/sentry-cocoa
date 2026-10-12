#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
import _SentryPrivate
import SentryTestUtilsObjC

extension Scope {
    @_spi(Private) public var propagationContext: SentryPropagationContext {
        get { requireTestBridgeValue(test_propagationContext()) }
        set { test_setPropagationContext(newValue) }
    }
}
#endif
