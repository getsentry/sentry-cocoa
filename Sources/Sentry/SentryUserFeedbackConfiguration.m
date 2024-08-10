#import "SentryUserFeedbackConfiguration.h"

#if SENTRY_HAS_UIKIT

#    import <CoreGraphics/CoreGraphics.h>

@implementation SentryUserFeedbackConfiguration

- (instancetype)init
{
    self = [super init];
    if (self) {
        // TODO: set defaults
    }
    return self;
}

@end

#endif // SENTRY_HAS_UIKIT
