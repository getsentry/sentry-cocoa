#import "SentryDefines.h"
#include "SentryProfilingConditionals.h"
#import "SentryTransactionContext.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryTransactionContext ()

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin;

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     sampled:(SentrySampleDecision)sampled
                  sampleRate:(nullable NSNumber *)sampleRate
                  sampleRand:(nullable NSNumber *)sampleRand;

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled
            parentSampleRate:(nullable NSNumber *)parentSampleRate
            parentSampleRand:(nullable NSNumber *)parentSampleRand;

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SentryTransactionNameSource)source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
                     sampled:(SentrySampleDecision)sampled
               parentSampled:(SentrySampleDecision)parentSampled
                  sampleRate:(nullable NSNumber *)sampleRate
            parentSampleRate:(nullable NSNumber *)parentSampleRate
                  sampleRand:(nullable NSNumber *)sampleRand
            parentSampleRand:(nullable NSNumber *)parentSampleRand;

#if SENTRY_TARGET_PROFILING_SUPPORTED
// This is currently only exposed for testing purposes, see -[SentryProfilerTests
// testProfilerMutationDuringSerialization]
@property (nonatomic, strong) SentryThread *threadInfo;

- (SentryThread *)sentry_threadInfo;
#endif

@end

// Swift-visible initializers. The anonymous extension above doesn't bridge across
// module boundaries, and nameSource uses a Swift-defined @objc enum that the
// _SentryPrivate Clang module cannot resolve. The renamed parameter (rawNameSource)
// gives these a distinct ObjC selector to avoid clashing with the extension methods.
@interface SentryTransactionContext (SwiftPrivate)

- (instancetype)initWithName:(NSString *)name
               rawNameSource:(SENTRY_SWIFT_MIGRATION_VALUE(SentryTransactionNameSource))source
                   operation:(NSString *)operation
                      origin:(NSString *)origin;

- (instancetype)initWithName:(NSString *)name
               rawNameSource:(SENTRY_SWIFT_MIGRATION_VALUE(SentryTransactionNameSource))source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     traceId:(SentryId *)traceId;

@end

NS_ASSUME_NONNULL_END
