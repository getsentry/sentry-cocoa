#include "SentryBacktrace.hpp"
#import "SentryProfiler.h"
#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED
void processBacktrace(const sentry::profiling::Backtrace &backtrace,
    NSMutableDictionary<NSString *, NSMutableDictionary *> *threadMetadata,
    NSMutableDictionary<NSString *, NSDictionary *> *queueMetadata,
    NSMutableArray<NSDictionary<NSString *, id> *> *samples,
    NSMutableArray<NSMutableArray<NSNumber *> *> *stacks,
    NSMutableArray<NSDictionary<NSString *, id> *> *frames,
    NSMutableDictionary<NSString *, NSNumber *> *frameIndexLookup, uint64_t startTimestamp,
    NSMutableDictionary<NSString *, NSNumber *> *stackIndexLookup);
#endif

@interface
SentryProfiler ()

/**
 * By default, the profiler will use an instance of @c SentrySystemWrapper. Use this method to swap
 * out for a different instance, like @c TestSentrySystemWrapper.
 */
+ (void)useSystemWrapper:(SentrySystemWrapper *)systemWrapper;

/**
 * By default, the profiler will use an instance of @c SentrySystemWrapper. Use this method to swap
 * out for a different instance, like @c TestSentrySystemWrapper.
 */
+ (void)useProcessInfoWrapper:(SentryNSProcessInfoWrapper *)processInfoWrapper;

@end
