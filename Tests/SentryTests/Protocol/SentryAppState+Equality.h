#import "SentryAppState.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryAppState (Equality)

- (BOOL)isEqual:(id _Nullable)object;

- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
