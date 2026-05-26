#import "SentryObjCSampleDecision.h"
#import "SentryObjCSpanContext.h"
#import "SentryObjCTransactionNameSource.h"
#import <Foundation/Foundation.h>

@class SentryObjCId;
@class SentryObjCSpanId;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCTransactionContext : SentryObjCSpanContext

@property (nonatomic, readonly, copy) NSString *name;
@property (nonatomic, readonly) SentryObjCTransactionNameSource nameSource;
@property (nonatomic, strong, nullable) NSNumber *sampleRate;
@property (nonatomic, strong, nullable) NSNumber *sampleRand;
@property (nonatomic) SentryObjCSampleDecision parentSampled;
@property (nonatomic, strong, nullable) NSNumber *parentSampleRate;
@property (nonatomic, strong, nullable) NSNumber *parentSampleRand;
@property (nonatomic, assign) BOOL forNextAppLaunch;

- (instancetype)initWithName:(NSString *)name operation:(NSString *)operation;
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     sampled:(SentryObjCSampleDecision)sampled
                  sampleRate:(nullable NSNumber *)sampleRate
                  sampleRand:(nullable NSNumber *)sampleRand;
- (instancetype)initWithName:(NSString *)name
                   operation:(NSString *)operation
                     traceId:(SentryObjCId *)traceId
                      spanId:(SentryObjCSpanId *)spanId
                parentSpanId:(nullable SentryObjCSpanId *)parentSpanId
               parentSampled:(SentryObjCSampleDecision)parentSampled
            parentSampleRate:(nullable NSNumber *)parentSampleRate
            parentSampleRand:(nullable NSNumber *)parentSampleRand;

@end

NS_ASSUME_NONNULL_END
