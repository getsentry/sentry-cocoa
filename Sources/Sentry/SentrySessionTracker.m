#import "SentrySessionTracker.h"
#import "SentryHub.h"
#import "SentryLog.h"
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
            currentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
{
    if (self = [super init]) {
        self.options = options;
        self.currentDateProvider = currentDateProvider;
    }
    return self;
}

- (void)start
{

#if SENTRY_HAS_UIKIT
    NSNotificationName didBecomeActiveNotificationName = UIApplicationDidBecomeActiveNotification;
    NSNotificationName willResignActiveNotificationName = UIApplicationWillResignActiveNotification;
    NSNotificationName willTerminateNotificationName = UIApplicationWillTerminateNotification;
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
    NSNotificationName didBecomeActiveNotificationName = NSApplicationDidBecomeActiveNotification;
    NSNotificationName willResignActiveNotificationName = NSApplicationWillResignActiveNotification;
    NSNotificationName willTerminateNotificationName = NSApplicationWillTerminateNotification;
#else
    [SentryLog logWithMessage:@"NO UIKit -> SentrySessionTracker will not "
                              @"track sessions automatically."
                     andLevel:kSentryLogLevelDebug];
#endif

#if SENTRY_HAS_UIKIT || TARGET_OS_OSX || TARGET_OS_MACCATALYST

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didBecomeActive)
                                               name:didBecomeActiveNotificationName
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(willResignActive)
                                               name:willResignActiveNotificationName
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(willTerminate)
                                               name:willTerminateNotificationName
                                             object:nil];

    SentryHub *hub = [SentrySDK currentHub];
    NSDate *_Nullable lastInForeground =
        [[[hub getClient] fileManager] readTimestampLastInForeground];
    if (nil != lastInForeground) {
        [[[hub getClient] fileManager] deleteTimestampLastInForeground];
    }

    [hub closeCachedSessionWithTimestamp:lastInForeground];

#endif
}

- (void)stop
{
#if SENTRY_HAS_UIKIT || TARGET_OS_OSX || TARGET_OS_MACCATALYST
    [NSNotificationCenter.defaultCenter removeObserver:self];
#endif
}

- (void)didBecomeActive
{
    SentryHub *hub = [SentrySDK currentHub];
    self.lastInForeground = [[[hub getClient] fileManager] readTimestampLastInForeground];

    if (nil == self.lastInForeground) {
        [hub startSession];
    } else {
        NSTimeInterval secondsInBackground =
            [[self.currentDateProvider date] timeIntervalSinceDate:self.lastInForeground];

        if (secondsInBackground * 1000 >= (double)(self.options.sessionTrackingIntervalMillis)) {
            [hub endSessionWithTimestamp:self.lastInForeground];
            [hub startSession];
        }
    }
}

- (void)willResignActive
{
    self.lastInForeground = [self.currentDateProvider date];
    SentryHub *hub = [SentrySDK currentHub];
    [[[hub getClient] fileManager] storeTimestampLastInForeground:self.lastInForeground];
}

- (void)willTerminate
{
    NSDate *sessionEnded
        = nil == self.lastInForeground ? [self.currentDateProvider date] : self.lastInForeground;
    SentryHub *hub = [SentrySDK currentHub];
    [hub endSessionWithTimestamp:sessionEnded];
    [[[hub getClient] fileManager] deleteTimestampLastInForeground];
}

@end
