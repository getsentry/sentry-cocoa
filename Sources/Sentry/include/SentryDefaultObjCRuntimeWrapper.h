#import "SentryDefines.h"
#import "SentryObjCRuntimeWrapper.h"

/**
 * A wrapper around the objc runtime functions for testability.
 */
@interface SentryDefaultObjCRuntimeWrapper : SENTRY_BASE_OBJECT <SentryObjCRuntimeWrapper>
SENTRY_NO_INIT

+ (instancetype)sharedInstance;

@end
