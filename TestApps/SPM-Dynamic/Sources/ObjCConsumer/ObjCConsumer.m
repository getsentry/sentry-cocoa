#import "ObjCConsumer.h"
#if SENTRY_SPM_V10
#    import <Sentry/Sentry-Swift.h>
#else
#    import <SentrySwift/SentrySwift-Swift.h>
#endif

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
