#import "SentryLogOutput.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryLogOutput

- (void)log:(NSString *)message
{
    printf("%s\n", message.UTF8String);
}

@end

NS_ASSUME_NONNULL_END
