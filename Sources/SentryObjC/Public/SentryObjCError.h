#import <Foundation/Foundation.h>

#if TARGET_OS_OSX || TARGET_OS_IOS
#    import <mach/kern_return.h>
#else
typedef int kern_return_t;
#endif

#import "SentryObjCDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Sentry SDK error codes.
 */
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

SENTRY_OBJC_EXTERN NSError *_Nullable NSErrorFromSentryError(
    SentryError error, NSString *description);
SENTRY_OBJC_EXTERN NSError *_Nullable NSErrorFromSentryErrorWithUnderlyingError(
    SentryError error, NSString *description, NSError *underlyingError);
SENTRY_OBJC_EXTERN NSError *_Nullable NSErrorFromSentryErrorWithException(
    SentryError error, NSString *description, NSException *exception);
SENTRY_OBJC_EXTERN NSError *_Nullable NSErrorFromSentryErrorWithKernelError(
    SentryError error, NSString *description, kern_return_t kernelErrorCode);

SENTRY_OBJC_EXTERN NSString *const SentryErrorDomain;

NS_ASSUME_NONNULL_END
