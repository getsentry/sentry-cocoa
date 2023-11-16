#import "SentryAutoSpanOnScopeStarter.h"
#import "SentryHub+Private.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryAutoSpanOnScopeStarter

- (void)startSpan:(SentrySpanCallback)callback
{
    [SentrySDK.currentHub.scope useSpan:callback];
}

@end

NS_ASSUME_NONNULL_END
