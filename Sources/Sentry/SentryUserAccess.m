#import "SentryUserAccess.h"
#import "SentryHub.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"

SentryUser *_Nullable sentry_getCurrentUser(void)
{
    return SentrySDKInternal.currentHub.scope.userObject;
}
