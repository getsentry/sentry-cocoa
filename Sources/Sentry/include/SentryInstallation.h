#import "SentryDefines.h"

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryInstallation : SENTRY_BASE_OBJECT

+ (NSString *)idWithCacheDirectoryPath:(NSString *)cacheDirectoryPath;

@end

NS_ASSUME_NONNULL_END
