#import "SentryMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryMessage (Equality)

- (BOOL)isEqual:(id _Nullable)object;

- (BOOL)isEqualToMessage:(SentryMessage *)message;

- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
