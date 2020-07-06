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
#if SENTRY_HAS_UIKIT

    NSNotificationName willEnterForegroundNotificationName
        = UIApplicationWillEnterForegroundNotification;
    NSNotificationName backgroundNotificationName = UIApplicationDidEnterBackgroundNotification;
    NSNotificationName willTerminateNotification = UIApplicationWillTerminateNotification;

   [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(willEnterForeground)
                                               name:willEnterForegroundNotificationName
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(didEnterBackground)
                                               name:backgroundNotificationName
                                             object:nil];

    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(willTerminate)
                                               name:willTerminateNotification
                                             object:nil];
#endif
}

- (void)stop
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
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
