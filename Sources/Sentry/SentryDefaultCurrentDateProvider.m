#import "SentryDefaultCurrentDateProvider.h"
#import "SentryTime.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryDefaultCurrentDateProvider ()

@end

@implementation SentryDefaultCurrentDateProvider

+ (instancetype)sharedInstance
{
    static SentryDefaultCurrentDateProvider *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (NSDate *_Nonnull)date
{
    return [NSDate date];
}

- (dispatch_time_t)dispatchTimeNow
{
    return dispatch_time(DISPATCH_TIME_NOW, 0);
}

- (NSInteger)timezoneOffset
{
    return [NSTimeZone localTimeZone].secondsFromGMT;
}

- (uint64_t)systemTime
{
    return getAbsoluteTime();
}

@end

NS_ASSUME_NONNULL_END
