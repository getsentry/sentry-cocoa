#import "SentryError.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const SentryErrorDomain = @"SentryErrorDomain";

NSError *_Nullable NSErrorFromSentryErrorWithUnderlyingError(
    SentryError error, NSString *description, NSError *underlyingError)
{
    return [NSError errorWithDomain:SentryErrorDomain
                               code:error
                           userInfo:@ {
                               NSLocalizedDescriptionKey : description,
                               NSUnderlyingErrorKey : underlyingError
                           }];
}

NSError *_Nullable NSErrorFromSentryErrorWithException(
    SentryError error, NSString *description, NSException *exception)
{
    return [NSError errorWithDomain:SentryErrorDomain
                               code:error
                           userInfo:@ {
                               NSLocalizedDescriptionKey : [NSString
                                   stringWithFormat:@"%@ (%@)", description, exception.reason],
                           }];
}

NSError *_Nullable NSErrorFromSentryError(SentryError error, NSString *description)
{
    return [NSError errorWithDomain:SentryErrorDomain
                               code:error
                           userInfo:@ { NSLocalizedDescriptionKey : description }];
}

NS_ASSUME_NONNULL_END
