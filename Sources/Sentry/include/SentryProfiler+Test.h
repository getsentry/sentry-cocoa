#include "SentryBacktrace.hpp"
#import "SentryProfiler.h"
#import "SentryProfiler+Private.h"
#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryDebugMeta;
@class SentryId;
@class SentrySample;
@class SentryTransaction;

NS_ASSUME_NONNULL_BEGIN

NSDictionary<NSString *, id> *serializedProfileData(NSDictionary<NSString *, id> *profileData,
    SentryTransaction *transaction, SentryId *profileID, NSString *truncationReason,
    NSString *environment, NSString *release, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<SentryDebugMeta *> *debugMeta);

NS_ASSUME_NONNULL_END

#endif
