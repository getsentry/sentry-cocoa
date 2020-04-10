#import "SentryHub.h"
#import "SentrySDK.h"
#import "SentrySessionTracker.h"
#import "SentryOptions.h"
#import "SentryLog.h"

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

@interface SentrySessionTracker ()

@property(nonatomic, strong) SentryOptions *options;
@property(atomic, strong) NSDate *lastInForeground;

@end

@implementation SentrySessionTracker

- (instancetype)initWithOptions:(SentryOptions *)options {
    if (self = [super init]) {
        self.options = options;
    }
    return self;
}

- (void)start {
#if SENTRY_HAS_UIKIT
    SentryHub *hub = [SentrySDK currentHub];
    [hub startSession];

    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationWillEnterForegroundNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    NSDate *from = nil == self.lastInForeground ? [NSDate date] : self.lastInForeground;
                                                    NSTimeInterval secondsInBackground = [[NSDate date] timeIntervalSinceDate:from];
                                                    if (secondsInBackground * 1000 > (double)(self.options.sessionTrackingIntervalMillis)) {
                                                        SentryHub *hub = [SentrySDK currentHub];
                                                        [hub endSessionWithTimestamp:from];
                                                        [hub startSession];
                                                    }
                                                    self.lastInForeground = nil;
                                                }];
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    self.lastInForeground = [NSDate date];
                                                }];
#else
    [SentryLog logWithMessage:@"NO UIKit -> SentrySessionTracker will not track sessions automatically." andLevel:kSentryLogLevelDebug];
#endif
}

@end
