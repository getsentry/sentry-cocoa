// This header extension contains C++ symbols so cannot be included in a Swift bridging header. To
// export things to Swift, see SwntryProfiler+SwiftTest.h.

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
