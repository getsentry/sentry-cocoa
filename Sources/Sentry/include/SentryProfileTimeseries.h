#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import <Foundation/Foundation.h>

@class SentrySample;
@class SentryTransaction;

#    if SENTRY_HAS_UIKIT
#        import "SentryMetricProfiler.h"
#        import "SentryScreenFrames.h"
#    endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

NSArray<SentrySample *> *_Nullable slicedProfileSamples(
    NSArray<SentrySample *> *samples, uint64_t startSystemTime, uint64_t endSystemTime);

#    if SENTRY_HAS_UIKIT

NSArray<SentrySerializedMetricEntry *> *sliceGPUData(SentryFrameInfoTimeSeries *frameInfo,
    uint64_t startSystemTime, uint64_t endSystemTime, BOOL useMostRecentRecording);

#    endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
