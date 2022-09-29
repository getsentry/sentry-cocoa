#import "SentryDescriptor.h"

@implementation SentryDescriptor

+ (SentryDescriptor *)shared
{
    static SentryDescriptor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (NSString *)getDescription:(id)object
{
    return [NSString stringWithFormat:@"%@", object];
}

@end
