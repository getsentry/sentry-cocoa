#include "SentryProfilingConditionals.h"
#import "SentryTransactionContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryTransactionContext ()

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin;

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     sampled:(SentrySampleDecision)sampled;

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(nonnull NSString *)operation
                      origin:(NSString *)origin
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled;

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
                     sampled:(SentrySampleDecision)sampled
               parentSampled:(SentrySampleDecision)parentSampled;

#if SENTRY_TARGET_PROFILING_SUPPORTED

// This is currently only exposed for testing purposes, see -[SentryProfilerTests
// testProfilerMutationDuringSerialization]. Can be null if there was a problem
// getting the current thread info from the underlying API.
@property (nonatomic, strong, nullable) SentryThread *threadInfo;

- (nullable SentryThread *)sentry_threadInfo;

#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

NS_ASSUME_NONNULL_END
