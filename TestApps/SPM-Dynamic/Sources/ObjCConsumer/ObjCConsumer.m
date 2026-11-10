#import "ObjCConsumer.h"
@import Sentry;

BOOL
sentryObjCConsumer(void)
{
#if !SDK_V10
    [SentrySDK close];
#endif
    return [SentrySDKLog willLogAtLevel:kSentryLevelFatal] &&
        [[SentryId alloc] init].sentryIdString.length == 32;
}
