#if SWIFT_PACKAGE && !SDK_V10
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

    @_spi(Private) public var fileManager: SentryFileManager {
        get { requireTestBridgeValue(test_fileManager()) }
        set { test_setFileManager(newValue) }
    }
    #endif
}
