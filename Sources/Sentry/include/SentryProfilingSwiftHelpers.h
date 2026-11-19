#import "SentryProfilingConditionals.h"
#import "SentryProfilingId.h"
#import <Foundation/Foundation.h>

@class SentryId;
@class SentryTracer;

NS_ASSUME_NONNULL_BEGIN

// SDK-side conversions and launch hooks keep SDK models out of the profiling implementation.
// Plain C entry points also bridge Objective-C++ to Swift under Swift Package Manager.

#ifdef __cplusplus
extern "C" {
#endif

SentryProfilingId *sentry_profilingIdFromSentryId(SentryId *sentryID);
void sentry_startLaunchProfile(void);
SentryTracer *_Nullable sentry_tracerForTransaction(id transaction);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
