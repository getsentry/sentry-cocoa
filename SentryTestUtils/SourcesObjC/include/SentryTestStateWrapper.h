#import <Foundation/Foundation.h>

@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT void wrapper_setCurrentHub(SentryHubInternal *_Nullable hub);
FOUNDATION_EXPORT void wrapper_clearPerformanceTracker(void);
FOUNDATION_EXPORT void wrapper_resetProfilingState(void);

NS_ASSUME_NONNULL_END
