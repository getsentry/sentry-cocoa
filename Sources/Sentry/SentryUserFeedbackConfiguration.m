#import "SentryUserFeedbackConfiguration.h"

#if SENTRY_HAS_UIKIT

#    import <CoreGraphics/CoreGraphics.h>

@implementation SentryUserFeedbackConfiguration

- (instancetype)init
{
    self = [super init];
    if (self) {
        _enableShakeGesture = NO;
        _floatingButtonInitialCoordinates = CGRectZero;
        _primaryColor = nil;
        _secondaryColor = nil;
        _tertiaryColor = nil;
    }
    return self;
}

@end

#endif // SENTRY_HAS_UIKIT
