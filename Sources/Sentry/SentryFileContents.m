#import "SentryFileContents.h"

@interface
SentryFileContents ()

@end

@implementation SentryFileContents

+ (void)load
{
    NSLog(@"%llu %s", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (instancetype)initWithPath:(NSString *)path andContents:(NSData *)contents
{
    if (self = [super init]) {
        _path = path;
        _contents = contents;
    }
    return self;
}

@end
