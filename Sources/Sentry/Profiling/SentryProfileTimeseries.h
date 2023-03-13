#import "SentryDefines.h"
#import <Foundation/Foundation.h>
#import <mutex>

@class SentryTransaction;

/**
 * Synchronizes reads and writes to the samples array; otherwise there will be a data race between
 * when the sampling profiler tries to insert a new sample, and when we iterate over the sample
 * array with fast enumeration to extract only those samples needed for a given transaction.
 */
SENTRY_EXTERN std::mutex _gSamplesArrayLock;

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
