#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain used when ``SentryTryCatch`` converts a caught @c NSException.
FOUNDATION_EXPORT NSErrorDomain const SentryNSExceptionErrorDomain;

/**
 * Executes @p block inside an ObjC @try / @catch, converting any raised
 * @c NSException into an @c NSError (domain @c SentryNSExceptionErrorDomain,
 * code 0). Returns @c nil and sets @p error on exception; otherwise returns
 * whatever the block returns.
 */
FOUNDATION_EXPORT id _Nullable SentryTryCatch(id _Nullable (NS_NOESCAPE ^block)(void),
    NSError *_Nullable *_Nullable error);

NS_ASSUME_NONNULL_END
