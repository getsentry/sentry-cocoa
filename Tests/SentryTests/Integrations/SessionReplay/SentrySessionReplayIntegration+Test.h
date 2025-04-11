#import "SentrySessionReplayIntegration.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentrySessionReplayIntegration (Test)

- (NSURL *)replayDirectory;
- (void)moveCurrentReplay;

@end

NS_ASSUME_NONNULL_END
