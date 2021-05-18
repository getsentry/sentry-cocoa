#import "SentryHub.h"

@class SentryId, SentryScope, SentryClient;

NS_ASSUME_NONNULL_BEGIN

@interface SentryHub (Private)

- (void)captureCrashEvent:(SentryEvent *)event;

- (void)setSampleRandomValue:(NSNumber *)value;

- (void)closeCachedSessionWithTimestamp:(NSDate *_Nullable)timestamp;

- (SentryClient *)client;
@end

NS_ASSUME_NONNULL_END
