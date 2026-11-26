#import "SentryClient+Private.h"

NS_ASSUME_NONNULL_BEGIN

// Referenced by SentryClient.m so static linkers load the category's object file.
@interface SentryClientErrorEventsLinker : NSObject
@end

@interface SentryClientInternal ()

- (void)setUserInfo:(nullable NSDictionary *)userInfo withEvent:(nullable SentryEvent *)event;

@end

@interface SentryClientInternal (ErrorEvents)

- (SentryEvent *)buildExceptionEvent:(NSException *)exception;

- (SentryEvent *)buildErrorEvent:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
