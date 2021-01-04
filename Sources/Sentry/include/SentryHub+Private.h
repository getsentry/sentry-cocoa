#import "SentryHub.h"

@class SentryId, SentryScope, SentryAttachment;

NS_ASSUME_NONNULL_BEGIN

@interface SentryHub (Private)

- (void)captureCrashEvent:(SentryEvent *)event
              attachments:(NSArray<SentryAttachment *> *)attachments;

@end

NS_ASSUME_NONNULL_END
