#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
#else
@_spi(Private) import Sentry
#endif
import _SentryPrivate
import SentryTestUtilsObjC

extension SentryClientInternal {
    #if SWIFT_PACKAGE
    public var options: Options {
        get { requireTestBridgeValue(getOptions()) }
        set { setOptions(newValue) }
    }
    #endif

    @_spi(Private) public var fileManager: SentryFileManager {
        get { requireTestBridgeValue(test_fileManager()) }
        set { test_setFileManager(newValue) }
    }
}
