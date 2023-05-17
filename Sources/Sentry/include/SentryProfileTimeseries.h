#import "SentryProfilingConditionals.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryDefines.h"
#    import <Foundation/Foundation.h>
#    import <mutex>

@class SentryTransaction;

NS_ASSUME_NONNULL_BEGIN

/** A storage class to hold the data associated with a single profiler sample. */
@interface SentrySample : NSObject
@property (nonatomic, assign) uint64_t absoluteTimestamp;
@property (nonatomic, strong) NSNumber *stackIndex;
@property (nonatomic, assign) uint64_t threadID;
@property (nullable, nonatomic, copy) NSString *queueAddress;
@end

NSArray<SentrySample *> *_Nullable slicedProfileSamples(
    NSArray<SentrySample *> *samples, SentryTransaction *transaction);

NS_ASSUME_NONNULL_END

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
