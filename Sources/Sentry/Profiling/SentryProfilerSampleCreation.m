#import "SentryProfilerSampleCreation.h"
#if SENTRY_TARGET_PROFILING_SUPPORTED
#    import "SentryInternalDefines.h"
#    import "SentrySwift.h"

SentrySample *
sentry_profilerSampleWithStack(NSArray<NSNumber *> *stack, uint64_t absoluteTimestamp,
    NSTimeInterval absoluteNSDateInterval, uint64_t threadID, SentryProfilerMutableState *state)
{
    SentrySample *sample = [[SentrySample alloc] init];
    sample.absoluteTimestamp = absoluteTimestamp;
    sample.absoluteNSDateInterval = absoluteNSDateInterval;
    sample.threadID = threadID;

    NSString *stackKey = [stack componentsJoinedByString:@"|"];
    NSNumber *_Nullable stackIndex = state.stackIndexLookup[stackKey];
    if (stackIndex) {
        sample.stackIndex = SENTRY_UNWRAP_NULLABLE(NSNumber, stackIndex);
    } else {
        NSNumber *nextStackIndex = @(state.stacks.count);
        sample.stackIndex = nextStackIndex;
        state.stackIndexLookup[stackKey] = nextStackIndex;
        [state.stacks addObject:stack];
    }

    return sample;
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
