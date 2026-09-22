#if SWIFT_PACKAGE
@_spi(Private) import SentrySwift
import SentryTestsObjCHelpers

@_spi(Private) extension SentryTestObjCRuntimeWrapper: SentryObjCRuntimeWrapper {}
#endif
