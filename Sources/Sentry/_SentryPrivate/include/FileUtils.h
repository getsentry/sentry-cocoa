#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

BOOL createDirectoryIfNotExists(NSString *path, NSError **error);

BOOL isErrorPathTooLong(NSError *error);

/**
 * Path for a default directory Sentry can use in the app sandbox' caches directory.
 * @note This method must be statically accessible because it will be called during app launch,
 * before any instance of @c SentryFileManager exists, and so wouldn't be able to access this path.
 * @note For unsandboxed macOS apps, the path has the form @c ~/Library/Caches/<app-bundle-id> .
 * from an objc property on it like the other paths. It also cannot use
 * @c SentryOptions.cacheDirectoryPath since this can be called before
 * @c SentrySDK.startWithOptions .
 */
SENTRY_EXTERN NSString *_Nullable sentryStaticCachesPath(void);

NS_ASSUME_NONNULL_END
