#import <Sentry/Sentry-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentrySDKSettings (Equality)

- (BOOL)isEqual:(id _Nullable)object;

- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
