#import <Foundation/Foundation.h>

#if TARGET_OS_OSX

#    import "SentryCrashExceptionApplication.h"
#    import "SentrySDK.h"
#    import "SentryUncaughtNSExceptions.h"

@implementation SentryCrashExceptionApplication

- (instancetype)init
{
    [[NSUserDefaults standardUserDefaults]
        registerDefaults:@{ @"NSApplicationCrashOnExceptions" : @YES }];
    return [super init];
}

- (void)reportException:(NSException *)exception
{
    [SentryUncaughtNSExceptions capture:exception];
    [super reportException:exception];
}

@end

#endif // TARGET_OS_OSX
