#import "SentryLogSinkFile.h"

@implementation SentryLogSinkFile {
    int fd;
}

- (instancetype)init
{
    self = [super init];
    if (self) { }
    return self;
}

- (void)log:(NSString *)message
{

    NSLog(@"%@", message);
}

@end
