#import "SentryUIKitSessionTracker.h"
#import "SentryHub.h"
#import "SentrySDK.h"
#import <UIKit/UIKit.h>

@interface
SentryUIKitSessionTracker ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDateProvider;
@property (atomic, strong) NSDate *lastInForeground;

@property (nonatomic, copy) NSNumber *wasWillEnterForegroundCalled;

@property (atomic, strong) id __block foregroundNotificationToken;
@property (atomic, strong) id __block backgroundNotificationToken;
@property (atomic, strong) id __block willTerminateNotificationToken;

@end

@implementation SentryUIKitSessionTracker

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

    self.backgroundNotificationToken = [NSNotificationCenter.defaultCenter
        addObserverForName:backgroundNotificationName
                    object:nil
                     queue:nil
                usingBlock:^(NSNotification *notification) { [blockSelf didEnterBackground]; }];
#endif
}

- (void)stop
{
#if SENTRY_HAS_UIKIT
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

- (void)didEnterBackground
{
    if ([self.wasWillEnterForegroundCalled boolValue]) {
        self.lastInForeground = [self.currentDateProvider date];
        SentryHub *hub = [SentrySDK currentHub];
        [[[hub getClient] fileManager] storeTimestampLastInForeground:self.lastInForeground];
    }

    self.wasWillEnterForegroundCalled = @NO;
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
