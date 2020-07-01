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

@property (nonatomic, copy) NSNumber *wasStartCalled;
@property (nonatomic, copy) NSNumber *wasDidBecomeActiveCalled;
@property (nonatomic, copy) NSNumber *isInBackground;

@end

@implementation SentrySessionTracker

- (instancetype)initWithOptions:(SentryOptions *)options
            currentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
{
    if (self = [super init]) {
        self.options = options;
        self.currentDateProvider = currentDateProvider;
        
        self.wasStartCalled = @NO;
        self.wasDidBecomeActiveCalled = @NO;
        self.isInBackground = @NO;
    }
    return self;
}

- (void)start
{
    __block id blockSelf = self;
#if SENTRY_HAS_UIKIT
    NSNotificationName willEnterForegroundNotificationName = UIApplicationWillEnterForegroundNotification;
    NSNotificationName backgroundNotificationName = UIApplicationDidEnterBackgroundNotification;
    NSNotificationName willTerminateNotification = UIApplicationWillTerminateNotification;
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
    NSNotificationName willEnterForegroundNotificationName = NSApplicationDidBecomeActiveNotification;
    NSNotificationName willTerminateNotification = NSApplicationWillTerminateNotification;
#else
    [SentryLog logWithMessage:@"NO UIKit -> SentrySessionTracker will not "
     @"track sessions automatically."
                     andLevel:kSentryLogLevelDebug];
#endif
    
#if SENTRY_HAS_UIKIT || TARGET_OS_OSX || TARGET_OS_MACCATALYST
    [NSNotificationCenter.defaultCenter
     addObserverForName:willEnterForegroundNotificationName
     object:nil
     queue:nil
     usingBlock:^(NSNotification *notification) { [blockSelf willEnterForeground]; }];
    
    [NSNotificationCenter.defaultCenter
     addObserverForName:willTerminateNotification
     object:nil
     queue:nil
     usingBlock:^(NSNotification *notification) { [blockSelf willTerminate]; }];
#endif
    
#if SENTRY_HAS_UIKIT
    [NSNotificationCenter.defaultCenter
     addObserverForName:backgroundNotificationName
     object:nil
     queue:nil
     usingBlock:^(NSNotification *notification) { [blockSelf didEnterBackground]; }];
#endif
}

- (void)willEnterForeground
{
    SentryHub *hub = [SentrySDK currentHub];
    
    self.lastInForeground = [[[hub getClient] fileManager] readTimestampLastInForeground];
    
    if (nil == self.lastInForeground) {
        [hub startSession];
    }
    else {
        NSTimeInterval timeSinceLastInForegroundInSeconds =
        [[self.currentDateProvider date] timeIntervalSinceDate:self.lastInForeground];
        
        if (timeSinceLastInForegroundInSeconds * 1000 >= (double)(self.options.sessionTrackingIntervalMillis)) {
            [hub startSession];
        }
    }
    
    self.lastInForeground = [self.currentDateProvider date];
    [[[hub getClient] fileManager] storeTimestampLastInForeground:self.lastInForeground];
}

#if SENTRY_HAS_UIKIT
- (void)didEnterBackground
{
    SentryHub *hub = [SentrySDK currentHub];
    [hub closeCachedSessionWithTimestamp:[self.currentDateProvider date]];
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
