#import <Foundation/Foundation.h>
#import <SentryObjC.h>

int
main(void)
{
    @autoreleasepool {
        [SentryObjCSDK startWithConfigureOptions:^(SentryObjCOptions *options) {
            options.dsn = @"https://sentry.io";
            options.debug = YES;
        }];

        [SentryObjCSDK close];
    }
    return 0;
}
