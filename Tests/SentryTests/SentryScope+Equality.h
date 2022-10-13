#import "SentryScope+Properties.h"
#import <Sentry/Sentry.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryScope (Equality)

- (BOOL)isEqual:(id _Nullable)other;
- (BOOL)isEqualToScope:(SentryScope *)scope;
- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
