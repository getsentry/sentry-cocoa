#import "SentryError.h"
#import "SentryDeprecated+Private.h"
#import "SentryMachLogging.hpp"

NS_ASSUME_NONNULL_BEGIN

NSString *const SentryErrorDomain = @"SentryErrorDomain";

static NSError *
sentry_errorWithUserInfo(SentryError error, NSDictionary *userInfo)
{
    return [NSError errorWithDomain:@"SentryErrorDomain" code:error userInfo:userInfo];
}

NSError *
sentry_errorWithDescription(SentryError error, NSString *description)
{
    return sentry_errorWithUserInfo(error, @ { NSLocalizedDescriptionKey : description });
}

NSError *
sentry_errorWithUnderlyingError(SentryError error, NSString *description, NSError *underlyingError)
{
    return sentry_errorWithUserInfo(error,
        @ { NSLocalizedDescriptionKey : description, NSUnderlyingErrorKey : underlyingError });
}

NSError *
sentry_errorWithException(SentryError error, NSString *description, NSException *exception)
{
    return sentry_errorWithDescription(
        error, [NSString stringWithFormat:@"%@ (%@)", description, exception.reason]);
}

@implementation SentryKernelErrorDescription

+ (NSString *)stringForKernelReturnCode:(int32_t)code
{
    NSString *description =
        [NSString stringWithUTF8String:sentry::kernelReturnCodeDescription(code)];
    return description ?: @"Unknown error.";
}

@end

NSError *
sentry_errorWithKernelError(SentryError error, NSString *description, kern_return_t kernelErrorCode)
{
    NSString *kernelDescription =
        [SentryKernelErrorDescription stringForKernelReturnCode:kernelErrorCode];
    return sentry_errorWithDescription(
        error, [NSString stringWithFormat:@"%@ (%@)", description, kernelDescription]);
}

NSError *_Nullable NSErrorFromSentryError(SentryError error, NSString *description)
{
    return sentry_errorWithDescription(error, description);
}

NSError *_Nullable NSErrorFromSentryErrorWithUnderlyingError(
    SentryError error, NSString *description, NSError *underlyingError)
{
    return sentry_errorWithUnderlyingError(error, description, underlyingError);
}

NSError *_Nullable NSErrorFromSentryErrorWithException(
    SentryError error, NSString *description, NSException *exception)
{
    return sentry_errorWithException(error, description, exception);
}

NSError *_Nullable NSErrorFromSentryErrorWithKernelError(
    SentryError error, NSString *description, kern_return_t kernelErrorCode)
{
    return sentry_errorWithKernelError(error, description, kernelErrorCode);
}

NS_ASSUME_NONNULL_END
