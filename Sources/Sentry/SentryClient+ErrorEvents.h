#import "SentryClient+Private.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryClientInternal (ErrorEvents)

- (SentryEvent *)buildExceptionEvent:(NSException *)exception;

- (SentryEvent *)buildErrorEvent:(NSError *)error;

- (void)setUserInfo:(nullable NSDictionary *)userInfo withEvent:(nullable SentryEvent *)event;

@end

NS_ASSUME_NONNULL_END
