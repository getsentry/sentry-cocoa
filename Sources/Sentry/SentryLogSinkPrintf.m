#import "SentryLogSinkPrintf.h"

@implementation SentryLogSinkPrintf

- (void)log:(NSString *)message
{
    printf("%s\n", message.UTF8String);
}

@end
