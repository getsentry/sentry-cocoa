#import "SentryUserAccess.h"
#import "SentryHub.h"
#import "SentrySDK+Private.h"
#import "SentryScope+PrivateSwift.h"

SentryUser *_Nullable sentry_getCurrentUser(void) { return SentrySDK.currentHub.scope.userObject; }
