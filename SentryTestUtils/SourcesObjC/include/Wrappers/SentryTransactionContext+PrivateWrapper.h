#import "SentryDefines.h"
#import "SentryTransactionContext.h"
@import _SentryPrivate;

NS_ASSUME_NONNULL_BEGIN

// Redeclare existing SDK selectors with module-safe types; implementations remain in the SDK.
@interface SentryTransactionContext (TestAccess)
- (SENTRY_SWIFT_MIGRATION_VALUE(SentryTransactionNameSource))nameSource NS_SWIFT_NAME(test_nameSource());

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SENTRY_SWIFT_MIGRATION_VALUE(SentryTransactionNameSource))source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
    NS_SWIFT_NAME(init(testName:rawNameSource:operation:origin:));

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SENTRY_SWIFT_MIGRATION_VALUE(SentryTransactionNameSource))source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     sampled:(SentrySampleDecision)sampled
                  sampleRate:(nullable NSNumber *)sampleRate
                  sampleRand:(nullable NSNumber *)sampleRand
    NS_SWIFT_NAME(init(testName:rawNameSource:operation:origin:sampled:sampleRate:sampleRand:));

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SENTRY_SWIFT_MIGRATION_VALUE(SentryTransactionNameSource))source
                   operation:(NSString *)operation
                      origin:(NSString *)origin
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled
            parentSampleRate:(nullable NSNumber *)parentSampleRate
            parentSampleRand:(nullable NSNumber *)parentSampleRand
    NS_SWIFT_NAME(init(testName:rawNameSource:operation:origin:trace:spanId:parentSpanId:parentSampled:parentSampleRate:parentSampleRand:));

- (instancetype)initWithName:(NSString *)name
                  nameSource:(SENTRY_SWIFT_MIGRATION_VALUE(SentryTransactionNameSource))source
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
            parentSampleRand:(nullable NSNumber *)parentSampleRand
    NS_SWIFT_NAME(init(testName:rawNameSource:operation:origin:trace:spanId:parentSpanId:sampled:parentSampled:sampleRate:parentSampleRate:sampleRand:parentSampleRand:));
@end

NS_ASSUME_NONNULL_END
