
#import "SentryUser.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryUser (Equality)

- (BOOL)isEqual:(id)other;

- (BOOL)isEqualToUser:(SentryUser *)user;

- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
