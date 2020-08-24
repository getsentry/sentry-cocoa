#import "SentrySession.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentrySession (Equality)

- (BOOL)isEqual:(id)object;

- (BOOL)isEqualToSession:(SentrySession *)session;

- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
