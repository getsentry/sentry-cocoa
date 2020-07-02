#import "SentrySessionTracker.h"
#import "SentryHub.h"
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

@property (atomic, strong) id __block foregroundNotificationToken;
@property (atomic, strong) id __block backgroundNotificationToken;
@property (atomic, strong) id __block willTerminateNotificationToken;

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
    __block id blockSelf = self;
#if SENTRY_HAS_UIKIT
    NSNotificationName foregroundNotificationName = UIApplicationDidBecomeActiveNotification;
    NSNotificationName backgroundNotificationName = UIApplicationWillResignActiveNotification;
    NSNotificationName willTerminateNotification = UIApplicationWillTerminateNotification;
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
    NSNotificationName foregroundNotificationName = NSApplicationDidBecomeActiveNotification;
    NSNotificationName backgroundNotificationName = NSApplicationWillResignActiveNotification;
    NSNotificationName willTerminateNotification = NSApplicationWillTerminateNotification;
#else
    [SentryLog logWithMessage:@"NO UIKit -> SentrySessionTracker will not "
                              @"track sessions automatically."
                     andLevel:kSentryLogLevelDebug];
#endif

#if SENTRY_HAS_UIKIT || TARGET_OS_OSX || TARGET_OS_MACCATALYST
    SentryHub *hub = [SentrySDK currentHub];
    NSDate *_Nullable lastInForeground =
        [[[hub getClient] fileManager] readTimestampLastInForeground];
    if (nil != lastInForeground) {
        [[[hub getClient] fileManager] deleteTimestampLastInForeground];
    }

    [hub closeCachedSessionWithTimestamp:lastInForeground];
    [hub startSession];

    self.foregroundNotificationToken = [NSNotificationCenter.defaultCenter
        addObserverForName:foregroundNotificationName
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *notification) { [blockSelf didBecomeActive]; }];
    self.backgroundNotificationToken = [NSNotificationCenter.defaultCenter
        addObserverForName:backgroundNotificationName
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *notification) { [blockSelf willResignActive]; }];
    self.willTerminateNotificationToken = [NSNotificationCenter.defaultCenter
        addObserverForName:willTerminateNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *notification) { [blockSelf willTerminate]; }];
#endif
}

- (void)stop
{
#if SENTRY_HAS_UIKIT || TARGET_OS_OSX || TARGET_OS_MACCATALYST
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self.foregroundNotificationToken];
    [center removeObserver:self.backgroundNotificationToken];
    [center removeObserver:self.willTerminateNotificationToken];
#endif
}

- (void)didBecomeActive
{
    NSDate *sessionEnded
        = nil == self.lastInForeground ? [self.currentDateProvider date] : self.lastInForeground;
    NSTimeInterval secondsInBackground =
        [[self.currentDateProvider date] timeIntervalSinceDate:sessionEnded];
    SentryHub *hub = [SentrySDK currentHub];
    if (secondsInBackground * 1000 > (double)(self.options.sessionTrackingIntervalMillis)) {
        [hub endSessionWithTimestamp:sessionEnded];
        [hub startSession];
    }
    [[[hub getClient] fileManager] deleteTimestampLastInForeground];
    self.lastInForeground = nil;
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
