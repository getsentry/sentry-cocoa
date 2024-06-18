#import "SentryLogSinkNSLog.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryLogSinkNSLog

- (void)log:(NSString *)message
{
    NSLog(@"%@", message);
}

@end

NS_ASSUME_NONNULL_END
