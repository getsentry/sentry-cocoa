#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryInternalDefines.h"
#    import "SentryProfiler+Private.h"
#    import <Foundation/Foundation.h>

@class SentryDebugMeta;

NS_ASSUME_NONNULL_BEGIN

SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeySlowFrameRenders;
SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeyFrozenFrameRenders;
SENTRY_EXTERN NSString *const kSentryProfilerSerializationKeyFrameRates;

@interface
SentryProfiler ()

#    if defined(TEST) || defined(TESTCI)

+ (SentryProfiler *)getCurrentProfiler;

/**
 * Provided as a pass-through to the SentryProfiledTracerConcurrency function of the same name,
 * because that file contains C++ which cannot be included in test targets via ObjC bridging headers
 * for usage in Swift.
 */
+ (void)resetConcurrencyTracking;

/**
 * Provided as a pass-through to the SentryProfiledTracerConcurrency function of the same name,
 * because that file contains C++ which cannot be included in test targets via ObjC bridging headers
 * for usage in Swift.
 */
+ (NSUInteger)currentProfiledTracers;

#    endif // defined(TEST) || defined(TESTCI)

SENTRY_EXTERN NSString *profilerTruncationReasonName(SentryProfilerTruncationReason reason);

/**
 * An intermediate function that can serve requests from either the native SDK or hybrid SDKs; they
 * will have different structures/objects available, these parameters are the common elements
 * needed to construct the payload dictionary.
 */
SENTRY_EXTERN NSMutableDictionary<NSString *, id> *serializedProfileData(
    NSDictionary<NSString *, id> *profileData, uint64_t startSystemTime, uint64_t endSystemTime,
    NSString *truncationReason, NSDictionary<NSString *, id> *serializedMetrics,
    NSArray<SentryDebugMeta *> *debugMeta, SentryHub *hub
#    if SENTRY_HAS_UIKIT
    ,
    SentryScreenFrames *gpuData
#    endif // SENTRY_HAS_UIKIT
);

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
