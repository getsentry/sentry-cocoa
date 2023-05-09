#include "SentryBacktrace.hpp"
#import "SentryProfiler.h"
#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentryDebugMeta;
@class SentryId;
@class SentrySample;
@class SentryTransaction;

NS_ASSUME_NONNULL_BEGIN

void processBacktrace(const sentry::profiling::Backtrace &backtrace,
    NSMutableDictionary<NSString *, NSMutableDictionary *> *threadMetadata,
    NSMutableDictionary<NSString *, NSDictionary *> *queueMetadata,
    NSMutableArray<SentrySample *> *samples, NSMutableArray<NSArray<NSNumber *> *> *stacks,
    NSMutableArray<NSDictionary<NSString *, id> *> *frames,
    NSMutableDictionary<NSString *, NSNumber *> *frameIndexLookup,
    NSMutableDictionary<NSString *, NSNumber *> *stackIndexLookup);

NSDictionary<NSString *, id> *serializedProfileData(NSDictionary<NSString *, id> *profileData,
    SentryTransaction *transaction, SentryId *profileID, NSString *truncationReason,
    NSString *environment, NSString *release, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<SentryDebugMeta *> *debugMeta);

NS_ASSUME_NONNULL_END

#endif
