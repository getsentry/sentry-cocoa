#import "SentrySessionTracker.h"
#import "SentryCurrentDateProvider.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentryOptions.h"
#import "SentrySDK.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
#    import <Cocoa/Cocoa.h>
#endif

@interface
SentrySessionTracker ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDateProvider;
@property (atomic, strong) NSDate *lastInForeground;

@end

@implementation SentrySessionTracker

- (instancetype)initWithOptions:(SentryOptions *)options
            currentDateProvider:
                (id<SentryCurrentDateProvider>)currentDateProvider
{
    if (self = [super init]) {
        self.options = options;
        self.currentDateProvider = currentDateProvider;
    }
    return self;
}

- (void)start
{
    __block id blockSelf = self;
#if SENTRY_HAS_UIKIT
    NSNotificationName foregroundNotificationName
        = UIApplicationDidBecomeActiveNotification;
    NSNotificationName backgroundNotificationName
        = UIApplicationWillResignActiveNotification;
    NSNotificationName willTerminateNotification
        = UIApplicationWillTerminateNotification;
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
    NSNotificationName foregroundNotificationName
        = NSApplicationDidBecomeActiveNotification;
    NSNotificationName backgroundNotificationName
        = NSApplicationWillResignActiveNotification;
    NSNotificationName willTerminateNotification
        = NSApplicationWillTerminateNotification;
#else
    [SentryLog logWithMessage:@"NO UIKit -> SentrySessionTracker will not "
                              @"track sessions automatically."
                     andLevel:kSentryLogLevelDebug];
#endif

#if SENTRY_HAS_UIKIT || TARGET_OS_OSX || TARGET_OS_MACCATALYST
    SentryHub *hub = [SentrySDK currentHub];
    [hub closeCachedSession];
    [hub startSession];
    [NSNotificationCenter.defaultCenter
        addObserverForName:foregroundNotificationName
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *notification) {
                    [blockSelf didBecomeActive];
                }];
    [NSNotificationCenter.defaultCenter
        addObserverForName:backgroundNotificationName
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *notification) {
                    [blockSelf willResignActive];
                }];
    [NSNotificationCenter.defaultCenter
        addObserverForName:willTerminateNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *notification) {
                    [blockSelf willTerminate];
                }];
#endif
}

- (void)didBecomeActive
{
    NSDate *sessionEnded = nil == self.lastInForeground
        ? [self.currentDateProvider date]
        : self.lastInForeground;
    NSTimeInterval secondsInBackground =
        [[self.currentDateProvider date] timeIntervalSinceDate:sessionEnded];
    if (secondsInBackground * 1000
        > (double)(self.options.sessionTrackingIntervalMillis)) {
        SentryHub *hub = [SentrySDK currentHub];
        [hub endSessionWithTimestamp:sessionEnded];
        [hub startSession];
    }
    self.lastInForeground = nil;
}

- (void)willResignActive
{
    self.lastInForeground = [self.currentDateProvider date];
}

- (void)willTerminate
{
    NSDate *sessionEnded = nil == self.lastInForeground
        ? [self.currentDateProvider date]
        : self.lastInForeground;
    [[SentrySDK currentHub] endSessionWithTimestamp:sessionEnded];
}

@end
