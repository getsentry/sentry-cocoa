#import "SentryLogSinkPrintf.h"

void logPrintf(const char *message) {
    printf("%s\n", message);
}

@implementation SentryLogSinkPrintf

- (void)log:(NSString *)message
{
    logPrintf(message.UTF8String);
}

@end
