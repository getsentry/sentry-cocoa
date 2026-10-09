#import "SentryId.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryId (Private)

+ (nullable NSUUID *)sentry_parseUUIDString:(NSString *)uuidString;

@end

NS_ASSUME_NONNULL_END
