#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryError) {
    kSentryErrorUnknownError = -1,
    kSentryErrorInvalidDsnError = 100,
    kSentryErrorSentryCrashNotInstalledError = 101,
    kSentryErrorInvalidCrashReportError = 102,
    kSentryErrorCompressionError = 103,
    kSentryErrorJsonConversionError = 104,
    kSentryErrorCouldNotFindDirectory = 105,
    kSentryErrorRequestError = 106,
    kSentryErrorEventNotSent = 107,
    kSentryErrorFileIO = 108,
    kSentryErrorKernel = 109,
};

SENTRY_EXTERN NSError *_Nullable NSErrorFromSentryError(SentryError error, NSString *description)
    DEPRECATED_MSG_ATTRIBUTE("Use SentryError.nsError(description:). This function will be "
                             "removed in a future major version.");
SENTRY_EXTERN NSError *_Nullable NSErrorFromSentryErrorWithUnderlyingError(
    SentryError error, NSString *description, NSError *underlyingError)
    DEPRECATED_MSG_ATTRIBUTE(
        "Use SentryError.nsError(description:underlyingError:). This function will be removed "
        "in a future major version.");
SENTRY_EXTERN NSError *_Nullable NSErrorFromSentryErrorWithException(
    SentryError error, NSString *description, NSException *exception)
    DEPRECATED_MSG_ATTRIBUTE(
        "Use SentryError.nsError(description:exception:). This function will be removed in a "
        "future major version.");
SENTRY_EXTERN NSError *_Nullable NSErrorFromSentryErrorWithKernelError(
    SentryError error, NSString *description, kern_return_t kernelErrorCode)
    DEPRECATED_MSG_ATTRIBUTE(
        "Use SentryError.nsError(description:kernelErrorCode:). This function will be removed "
        "in a future major version.");

SENTRY_EXTERN NSString *const SentryErrorDomain DEPRECATED_MSG_ATTRIBUTE(
    "Use SentryError.domain. This constant will be removed in a future major version.");

NS_ASSUME_NONNULL_END
