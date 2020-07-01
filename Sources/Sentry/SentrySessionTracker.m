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

@property (nonatomic, copy) NSNumber *wasWillEnterForegroundCalled;

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

        self.wasWillEnterForegroundCalled = @NO;
    }
    return self;
}

- (void)start
{
    __block id blockSelf = self;
#if SENTRY_HAS_UIKIT
    NSNotificationName willEnterForegroundNotificationName
        = UIApplicationWillEnterForegroundNotification;
    NSNotificationName backgroundNotificationName = UIApplicationDidEnterBackgroundNotification;
    NSNotificationName willTerminateNotification = UIApplicationWillTerminateNotification;
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
    NSNotificationName willEnterForegroundNotificationName
        = NSApplicationDidBecomeActiveNotification;
    NSNotificationName willTerminateNotification = NSApplicationWillTerminateNotification;
#else
    [SentryLog logWithMessage:@"NO UIKit -> SentrySessionTracker will not "
                              @"track sessions automatically."
                     andLevel:kSentryLogLevelDebug];
#endif

#if SENTRY_HAS_UIKIT || TARGET_OS_OSX || TARGET_OS_MACCATALYST
    self.foregroundNotificationToken = [NSNotificationCenter.defaultCenter
        addObserverForName:willEnterForegroundNotificationName
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *notification) { [blockSelf willEnterForeground]; }];

    self.willTerminateNotificationToken = [NSNotificationCenter.defaultCenter
        addObserverForName:willTerminateNotification
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *notification) { [blockSelf willTerminate]; }];
#endif

#if SENTRY_HAS_UIKIT
    self.backgroundNotificationToken =  [NSNotificationCenter.defaultCenter
        addObserverForName:backgroundNotificationName
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *notification) { [blockSelf didEnterBackground]; }];
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

- (void)willEnterForeground
{
    SentryHub *hub = [SentrySDK currentHub];

    self.lastInForeground = [[[hub getClient] fileManager] readTimestampLastInForeground];

    if (nil == self.lastInForeground) {
        [hub startSession];
    } else {
        NSTimeInterval timeSinceLastInForegroundInSeconds =
            [self.lastInForeground timeIntervalSinceDate:hub.session.started];

        if (timeSinceLastInForegroundInSeconds * 1000
            >= (double)(self.options.sessionTrackingIntervalMillis)) {
            [hub endSessionWithTimestamp:self.lastInForeground];
            [hub startSession];
        }
    }

    self.wasWillEnterForegroundCalled = @YES;
}

#if SENTRY_HAS_UIKIT
- (void)didEnterBackground
{
    if ([self.wasWillEnterForegroundCalled boolValue]) {
        self.lastInForeground = [self.currentDateProvider date];
        SentryHub *hub = [SentrySDK currentHub];
        [[[hub getClient] fileManager] storeTimestampLastInForeground:self.lastInForeground];
    }

    self.wasWillEnterForegroundCalled = @NO;
}
#endif

- (void)willTerminate
{
    NSDate *sessionEnded
        = nil == self.lastInForeground ? [self.currentDateProvider date] : self.lastInForeground;
    SentryHub *hub = [SentrySDK currentHub];
    [hub endSessionWithTimestamp:sessionEnded];
    [[[hub getClient] fileManager] deleteTimestampLastInForeground];
}

@end
