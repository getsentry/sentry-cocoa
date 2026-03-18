#import <Foundation/Foundation.h>

#if TARGET_OS_OSX || TARGET_OS_IOS
#    import <mach/kern_return.h>
#else
typedef int kern_return_t;
#endif

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Sentry SDK error codes.
 */
typedef NS_ENUM(NSInteger, SentryError) {
    /// Unknown or unclassified error.
    kSentryErrorUnknownError = -1,
    /// Invalid or malformed DSN string.
    kSentryErrorInvalidDsnError = 100,
    /// SentryCrash crash handler not installed.
    kSentryErrorSentryCrashNotInstalledError = 101,
    /// Crash report data is invalid or corrupted.
    kSentryErrorInvalidCrashReportError = 102,
    /// Failed to compress data for transmission.
    kSentryErrorCompressionError = 103,
    /// JSON serialization/deserialization failed.
    kSentryErrorJsonConversionError = 104,
    /// Required directory not found.
    kSentryErrorCouldNotFindDirectory = 105,
    /// Network request failed.
    kSentryErrorRequestError = 106,
    /// Event could not be sent to Sentry.
    kSentryErrorEventNotSent = 107,
    /// File I/O operation failed.
    kSentryErrorFileIO = 108,
    /// Kernel-level error occurred.
    kSentryErrorKernel = 109,
};

/**
 * Creates an @c NSError from a Sentry error code.
 *
 * @param error The error code.
 * @param description Error description.
 * @return An @c NSError instance with domain @c SentryErrorDomain.
 */
SENTRY_OBJC_EXTERN NSError *_Nullable NSErrorFromSentryError(
    SentryError error, NSString *description);

/**
 * Creates an @c NSError with an underlying error.
 *
 * @param error The error code.
 * @param description Error description.
 * @param underlyingError The underlying cause of this error.
 * @return An @c NSError instance with the underlying error in @c userInfo.
 */
SENTRY_OBJC_EXTERN NSError *_Nullable NSErrorFromSentryErrorWithUnderlyingError(
    SentryError error, NSString *description, NSError *underlyingError);

/**
 * Creates an @c NSError from an exception.
 *
 * @param error The error code.
 * @param description Error description.
 * @param exception The exception that caused this error.
 * @return An @c NSError instance with the exception in @c userInfo.
 */
SENTRY_OBJC_EXTERN NSError *_Nullable NSErrorFromSentryErrorWithException(
    SentryError error, NSString *description, NSException *exception);

/**
 * Creates an @c NSError from a kernel error code.
 *
 * @param error The error code.
 * @param description Error description.
 * @param kernelErrorCode The Mach kernel error code.
 * @return An @c NSError instance with the kernel error in @c userInfo.
 */
SENTRY_OBJC_EXTERN NSError *_Nullable NSErrorFromSentryErrorWithKernelError(
    SentryError error, NSString *description, kern_return_t kernelErrorCode);

/// The error domain for Sentry SDK errors.
SENTRY_OBJC_EXTERN NSString *const SentryErrorDomain;

NS_ASSUME_NONNULL_END
