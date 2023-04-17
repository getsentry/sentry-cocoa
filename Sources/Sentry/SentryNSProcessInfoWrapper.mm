#import "SentryNSProcessInfoWrapper.h"

@implementation SentryNSProcessInfoWrapper

+ (SentryNSProcessInfoWrapper *)shared
{
    static SentryNSProcessInfoWrapper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (NSString *)processDirectoryPath
{
    return NSBundle.mainBundle.bundlePath;
}

- (NSString *)processPath
{
    return NSBundle.mainBundle.executablePath;
}

- (NSUInteger)processorCount
{
    return NSProcessInfo.processInfo.processorCount;
}

@end
