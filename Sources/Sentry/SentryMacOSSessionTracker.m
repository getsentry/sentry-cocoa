#import <Foundation/Foundation.h>

#import "SentryMacOSSessionTracker.h"

@interface
SentryMacOSSessionTracker ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDateProvider;
@property (atomic, strong) NSDate *lastInForeground;

@property (atomic, strong) id __block foregroundNotificationToken;
@property (atomic, strong) id __block backgroundNotificationToken;
@property (atomic, strong) id __block willTerminateNotificationToken;

@end

@implementation SentryMacOSSessionTracker

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
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
    NSNotificationName willEnterForegroundNotificationName
        = NSApplicationDidBecomeActiveNotification;
    NSNotificationName willTerminateNotification = NSApplicationWillTerminateNotification;
#endif
}

- (void)stop
{
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self.foregroundNotificationToken];
    [center removeObserver:self.backgroundNotificationToken];
    [center removeObserver:self.willTerminateNotificationToken];

#endif
}

@end
