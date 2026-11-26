#import "SentryId.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryId (Private)

@property (nonatomic, readonly) NSUUID *uuid;

+ (nullable NSUUID *)sentry_parseUUIDString:(NSString *)uuidString;

@end

NS_ASSUME_NONNULL_END
