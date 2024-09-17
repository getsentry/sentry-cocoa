#import "SentryAttachment.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryAttachment (Equality)

- (BOOL)isEqual:(id _Nullable)other;

- (BOOL)isEqualToAttachment:(SentryAttachment *)attachment;

- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
