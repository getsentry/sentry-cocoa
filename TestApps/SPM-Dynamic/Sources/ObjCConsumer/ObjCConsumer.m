#import "ObjCConsumer.h"
#import <SentrySwift/SentrySwift-Swift.h>

BOOL
sentryObjCConsumer(void)
{
    return [SentrySDKLog willLogAtLevel:kSentryLevelFatal] &&
        [[SentryId alloc] init].sentryIdString.length == 32;
}

int
sentrySDKGeneration(void)
{
#if SDK_V10
    return 10;
#else
    return 9;
#endif
}
