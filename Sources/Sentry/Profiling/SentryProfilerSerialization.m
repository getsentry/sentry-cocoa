#import "SentryProfilerSerialization+Private.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryFormatter.h"
#    import "SentryInternalDefines.h"
#    import "SentryLogC.h"
#    import "SentryProfileTimeseries.h"
#    import "SentryProfilingSample.h"
#    import "SentryTime.h"

NSString *const kSentryProfilerSerializationKeySlowFrameRenders = @"slow_frame_renders";
NSString *const kSentryProfilerSerializationKeyFrozenFrameRenders = @"frozen_frame_renders";
NSString *const kSentryProfilerSerializationKeyFrameRates = @"screen_frame_rates";

#    pragma mark - Private

/**
 * Given an array of samples with absolute timestamps, return the serialized JSON mapping with
 * their data, with timestamps normalized relative to the provided transaction's start time.
 * */
NSArray<NSDictionary *> *
_sentry_serializedTraceProfileSamplesWithRelativeTimestamps(
    NSArray<SentryProfilingSample *> *samples, uint64_t startSystemTime)
{
    NSMutableArray<NSDictionary *> *result = [NSMutableArray<NSDictionary *> array];
    [samples enumerateObjectsUsingBlock:^(
        SentryProfilingSample *_Nonnull sample, NSUInteger idx, BOOL *_Nonnull stop) {
        // This shouldn't happen as we would've filtered out any such samples, but we should still
        // guard against it before calling getDurationNs as a defensive measure
        if (!orderedChronologically(startSystemTime, sample.absoluteTimestamp)) {
            SENTRY_LOG_WARN(@"Filtering sample as it came before start time to begin slicing.");
            return;
        }
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        uint64_t durationNs = getDurationNs(startSystemTime, sample.absoluteTimestamp);
        dict[@"elapsed_since_start_ns"] = sentry_stringForUInt64(durationNs);

        dict[@"thread_id"] = sentry_stringForUInt64(sample.threadID);
        dict[@"stack_id"] = sample.stackIndex;

        if (sample.queueAddress) {
            dict[@"queue_address"] = sample.queueAddress;
        }

        [result addObject:dict];
    }];
    return result;
}

/**
 * Given an array of continuous profile samples with absolute NSDate timestamps, return the
 * serialized JSON mapping with their data.
 * */
NSArray<NSDictionary *> *
_sentry_serializedContinuousProfileSamples(NSArray<SentryProfilingSample *> *samples)
{
    NSMutableArray<NSDictionary *> *result = [NSMutableArray<NSDictionary *> array];
    [samples enumerateObjectsUsingBlock:^(
        SentryProfilingSample *_Nonnull sample, NSUInteger idx, BOOL *_Nonnull stop) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        dict[@"timestamp"] = @(sample.absoluteNSDateInterval);
        dict[@"thread_id"] = sentry_stringForUInt64(sample.threadID);
        dict[@"stack_id"] = sample.stackIndex;
        if (sample.queueAddress) {
            dict[@"queue_address"] = sample.queueAddress;
        }
        [result addObject:dict];
    }];
    return result;
}

#    pragma mark - Exported for tests

NSString *
sentry_profilerTruncationReasonName(SentryProfilerTruncationReason reason)
{
    switch (reason) {
    case SentryProfilerTruncationReasonNormal:
        return @"normal";
    case SentryProfilerTruncationReasonAppMovedToBackground:
        return @"backgrounded";
    case SentryProfilerTruncationReasonTimeout:
        return @"timeout";
    }
}

NSMutableDictionary<NSString *, id> *_Nullable sentry_serializedTraceProfileData(
    NSDictionary<NSString *, id> *profileData, uint64_t startSystemTime, uint64_t endSystemTime,
    NSString *truncationReason, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<NSDictionary<NSString *, id> *> *_Nullable debugImages
#    if SENTRY_HAS_UIKIT
    ,
    SentryProfilingFrameMeasurements *_Nullable gpuData
#    endif // SENTRY_HAS_UIKIT
)
{
    NSMutableArray<SentryProfilingSample *> *const samples = profileData[@"profile"][@"samples"];
    // We need at least two samples to be able to draw a stack frame for any given function: one
    // sample for the start of the frame and another for the end. Otherwise we would only have a
    // stack frame with 0 duration, which wouldn't make sense.
    if ([samples count] < 2) {
        SENTRY_LOG_DEBUG(@"Not enough samples in profile");
        return nil;
    }

    // slice the profile data to only include the samples/metrics within the transaction
    NSArray<SentryProfilingSample *> *slicedSamples
        = sentry_slicedProfileSamples(samples, startSystemTime, endSystemTime);
    if (slicedSamples.count < 2) {
        SENTRY_LOG_DEBUG(@"Not enough samples in profile during the transaction");
        return nil;
    }
    NSMutableDictionary<NSString *, id> *payload = [NSMutableDictionary<NSString *, id> dictionary];
    NSMutableDictionary<NSString *, id> *const profile = [profileData[@"profile"] mutableCopy];
    profile[@"samples"] = _sentry_serializedTraceProfileSamplesWithRelativeTimestamps(
        slicedSamples, startSystemTime);
    payload[@"profile"] = profile;

    payload[@"version"] = @"1";
    if (debugImages.count > 0) {
        payload[@"debug_meta"] = @ { @"images" : SENTRY_UNWRAP_NULLABLE(NSArray, debugImages) };
    }

    payload[@"truncation_reason"] = truncationReason;

    // add the gathered metrics
    NSDictionary<NSString *, id> *metrics = serializedMetrics;

#    if SENTRY_HAS_UIKIT
    if (gpuData != nil) {
        SentryProfilingFrameMeasurements *_Nonnull frames
            = SENTRY_UNWRAP_NULLABLE(SentryProfilingFrameMeasurements, gpuData);
        NSMutableDictionary<NSString *, id> *mutableMetrics =
            [NSMutableDictionary<NSString *, id> dictionaryWithDictionary:metrics];
        NSArray<SentrySerializedMetricEntry *> *slowFrames
            = sentry_sliceTraceProfileGPUData(frames.slowFrameTimestamps, startSystemTime,
                endSystemTime, /*useMostRecentFrameRate */ NO);
        if (slowFrames.count > 0) {
            mutableMetrics[kSentryProfilerSerializationKeySlowFrameRenders] =
                @ { @"unit" : @"nanosecond", @"values" : slowFrames };
        }

        NSArray<SentrySerializedMetricEntry *> *frozenFrames = sentry_sliceTraceProfileGPUData(
            frames.frozenFrameTimestamps, startSystemTime, endSystemTime,
            /*useMostRecentFrameRate */ NO);
        if (frozenFrames.count > 0) {
            mutableMetrics[kSentryProfilerSerializationKeyFrozenFrameRenders] =
                @ { @"unit" : @"nanosecond", @"values" : frozenFrames };
        }

        if (slowFrames.count > 0 || frozenFrames.count > 0) {
            NSArray<SentrySerializedMetricEntry *> *frameRates = sentry_sliceTraceProfileGPUData(
                frames.frameRateTimestamps, startSystemTime, endSystemTime,
                /*useMostRecentFrameRate */ YES);
            if (frameRates.count > 0) {
                mutableMetrics[kSentryProfilerSerializationKeyFrameRates] =
                    @ { @"unit" : @"hz", @"values" : frameRates };
            }
        }
        metrics = mutableMetrics;
    }
#    endif // SENTRY_HAS_UIKIT

    if (metrics.count > 0) {
        payload[@"measurements"] = metrics;
    }

    return payload;
}

NSMutableDictionary<NSString *, id> *
sentry_serializedContinuousProfileChunk(
    NSDictionary<NSString *, id> *profileData, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<NSDictionary<NSString *, id> *> *_Nullable debugImages
#    if SENTRY_HAS_UIKIT
    ,
    SentryProfilingFrameMeasurements *_Nullable gpuData
#    endif // SENTRY_HAS_UIKIT
)
{
    NSMutableArray<SentryProfilingSample *> *const samples = profileData[@"profile"][@"samples"];
    // !!!: assumption: in trace profiling, we would avoid sending a payload with less than 2
    // samples. now, we may have previously sent a chunk with many samples, and then this chunk may
    // be the last of the continuous profiling session and it only has 1 sample. assuming we'll want
    // to keep that sample. let the backend decide, or, keep track of some statistics of the
    // profiling session, to count the number of total samples sent so far, to decide whether or not
    // a 1-sample chunk is acceptable.

    NSMutableDictionary<NSString *, id> *payload = [NSMutableDictionary<NSString *, id> dictionary];
    NSMutableDictionary<NSString *, id> *const profile = [profileData[@"profile"] mutableCopy];
    profile[@"samples"] = _sentry_serializedContinuousProfileSamples(samples);

    payload[@"profile"] = profile;

    payload[@"version"] = @"2";
    if (debugImages.count > 0) {
        payload[@"debug_meta"] = @ { @"images" : SENTRY_UNWRAP_NULLABLE(NSArray, debugImages) };
    }

    // add the gathered metrics
    NSDictionary<NSString *, id> *metrics = serializedMetrics;

#    if SENTRY_HAS_UIKIT
    if (gpuData != nil) {
        SentryProfilingFrameMeasurements *_Nonnull frames
            = SENTRY_UNWRAP_NULLABLE(SentryProfilingFrameMeasurements, gpuData);
        NSMutableDictionary<NSString *, id> *mutableMetrics =
            [NSMutableDictionary<NSString *, id> dictionaryWithDictionary:metrics];
        if (frames.slowFrameTimestamps.count > 0) {
            NSMutableDictionary *values = [NSMutableDictionary dictionary];
            values[@"unit"] = @"nanosecond";
            values[@"values"] = frames.slowFrameTimestamps;
            mutableMetrics[kSentryProfilerSerializationKeySlowFrameRenders] = values;
        }

        if (frames.frozenFrameTimestamps.count > 0) {
            NSMutableDictionary *values = [NSMutableDictionary dictionary];
            values[@"unit"] = @"nanosecond";
            values[@"values"] = frames.frozenFrameTimestamps;
            mutableMetrics[kSentryProfilerSerializationKeyFrozenFrameRenders] = values;
        }

        if (frames.slowFrameTimestamps.count > 0 || frames.frozenFrameTimestamps.count > 0) {
            if (frames.frameRateTimestamps.count > 0) {
                NSMutableDictionary *values = [NSMutableDictionary dictionary];
                values[@"unit"] = @"hz";
                values[@"values"] = frames.frameRateTimestamps;
                mutableMetrics[kSentryProfilerSerializationKeyFrameRates] = values;
            }
        }
        metrics = mutableMetrics;
    }
#    endif // SENTRY_HAS_UIKIT

    if (metrics.count > 0) {
        payload[@"measurements"] = metrics;
    }

    return payload;
}

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
