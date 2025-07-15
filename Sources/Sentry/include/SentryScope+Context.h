#import "SentryScope.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryScope ()

- (NSDictionary<NSString *, id> *_Nullable)getContextForKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END