#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"
#import "SentryObjCSampleDecision.h"
#import "SentryObjCSpanContext.h"
#import "SentryObjCTransactionNameSource.h"

@class SentryId;
@class SentrySpanId;

NS_ASSUME_NONNULL_BEGIN

/**
 * Context for a transaction (root span).
 *
 * @see SentrySDK
 * @see SentrySpanContext
 */
@interface SentryTransactionContext : SentrySpanContext

SENTRY_NO_INIT

/** Transaction name. */
@property (nonatomic, readonly) NSString *name;

/** Source of the transaction name. */
@property (nonatomic, readonly) SentryTransactionNameSource nameSource;

/** Rate of sampling. */
@property (nonatomic, strong, nullable) NSNumber *sampleRate;

/** Random value used to determine if the span is sampled. */
@property (nonatomic, strong, nullable) NSNumber *sampleRand;

/** Whether the parent is sampled. */
@property (nonatomic) SentrySampleDecision parentSampled;

/** Parent sample rate. */
@property (nonatomic, strong, nullable) NSNumber *parentSampleRate;

/** Parent random value for sampling. */
@property (nonatomic, strong, nullable) NSNumber *parentSampleRand;

/** Used for app launch profiling sampling. */
@property (nonatomic, assign) BOOL forNextAppLaunch;

/** Initializes with name and operation. */
- (instancetype)initWithName:(NSString *)name operation:(NSString *)operation;

/** Initializes with sampling parameters. */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SentrySampleDecision)sampled
                  sampleRate:(nullable NSNumber *)sampleRate
                  sampleRand:(nullable NSNumber *)sampleRand;

/** Full initializer with trace/span IDs. */
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     traceId:(SentryId *)traceId
                      spanId:(SentrySpanId *)spanId
                parentSpanId:(nullable SentrySpanId *)parentSpanId
               parentSampled:(SentrySampleDecision)parentSampled
            parentSampleRate:(nullable NSNumber *)parentSampleRate
            parentSampleRand:(nullable NSNumber *)parentSampleRand;

@end

NS_ASSUME_NONNULL_END
