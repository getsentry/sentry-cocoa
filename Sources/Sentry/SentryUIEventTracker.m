#import "SentrySwizzleWrapper.h"
#import <SentryUIEventTracker.h>
#import <SentrySDK.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryUIEventTrackerSwizzleSendAction
    = @"SentryUIEventTrackerSwizzleSendAction";

@interface
SentryUIEventTracker ()

@property (nonatomic, strong) SentrySwizzleWrapper *swizzleWrapper;

@end

@implementation SentryUIEventTracker

- (instancetype)initWithSwizzleWrapper:(SentrySwizzleWrapper *)swizzleWrapper
{
    if (self = [super init]) {
        self.swizzleWrapper = swizzleWrapper;
    }
    return self;
}

- (void)start
{
#if SENTRY_HAS_UIKIT
    [self.swizzleWrapper
        swizzleSendAction:^(NSString *action, UIEvent *event) {
        
        for (UITouch *touch in event.allTouches) {
            if (touch.phase == UITouchPhaseCancelled || touch.phase == UITouchPhaseEnded) {
                
            }
        }
        
        if (event.view.accessibilityIdentifier && ![event.accessibilityIdentifier isEqualToString:@""]) {
            
        }
        
        id<SentrySpan> transaction = [SentrySDK startTransactionWithName:@"" operation:@"ui.action.click" bindToScope:YES];
        
        }
                   forKey:SentryUIEventTrackerSwizzleSendAction];
#endif
}

- (void)stop
{
#if SENTRY_HAS_UIKIT
    [self.swizzleWrapper removeSwizzleSendActionForKey:SentryUIEventTrackerSwizzleSendAction];
#endif
}

@end

NS_ASSUME_NONNULL_END
