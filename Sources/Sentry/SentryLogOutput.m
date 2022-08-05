#import "SentryLogOutput.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryLogOutput

- (void)log:(NSString *)message
{
#if defined(TEST) || defined(TESTCI)
    static NSISO8601DateFormatter *df;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ df = [[NSISO8601DateFormatter alloc] init]; });
    printf("%s: %s\n", [df stringFromDate:[NSDate date]].UTF8String, message.UTF8String);
#else
    NSLog(@"%@", message);
#endif
}

@end

NS_ASSUME_NONNULL_END
