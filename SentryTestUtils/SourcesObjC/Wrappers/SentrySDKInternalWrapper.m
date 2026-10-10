#import "Wrappers/SentrySDKInternalWrapper.h"

void
wrapper_setCurrentHub(SentryHubInternal *_Nullable hub)
{
    [SentrySDKInternal setCurrentHub:hub];
}
