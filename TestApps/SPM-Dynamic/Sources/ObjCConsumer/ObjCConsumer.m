#import "ObjCConsumer.h"
#if SDK_V10
@import Sentry;
#else
@import SentrySwift;
#endif

BOOL
sentryObjCConsumer(void)
{
#if !SDK_V10
    [SentrySDK close];
#endif
    return [SentrySDKLog willLogAtLevel:kSentryLevelFatal] &&
        [[SentryId alloc] init].sentryIdString.length == 32;
}
