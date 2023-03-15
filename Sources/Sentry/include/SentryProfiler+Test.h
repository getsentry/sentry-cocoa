#include "SentryBacktrace.hpp"
#import "SentryProfiler.h"
#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@class SentrySample;

NS_ASSUME_NONNULL_BEGIN

void processBacktrace(const sentry::profiling::Backtrace &backtrace,
    NSMutableDictionary<NSString *, NSMutableDictionary *> *threadMetadata,
    NSMutableDictionary<NSString *, NSDictionary *> *queueMetadata,
    NSMutableArray<SentrySample *> *samples, NSMutableArray<NSMutableArray<NSNumber *> *> *stacks,
    NSMutableArray<NSDictionary<NSString *, id> *> *frames,
    NSMutableDictionary<NSString *, NSNumber *> *frameIndexLookup,
    NSMutableDictionary<NSString *, NSNumber *> *stackIndexLookup);

NS_ASSUME_NONNULL_END

#endif
