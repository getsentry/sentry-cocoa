/**
 * SentrySwiftUI needs a class from Sentry that is not public.
 * The easiest way do expose this class is by copying it interface.
 * We could just add the original header file to SwntrySwiftUI project,
 * but the original file has reference to other header that we don't need here.
 */

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SentryTransactionNameSource) {
    kSentryTransactionNameSourceCustom = 0,
    kSentryTransactionNameSourceUrl,
    kSentryTransactionNameSourceRoute,
    kSentryTransactionNameSourceView,
    kSentryTransactionNameSourceComponent,
    kSentryTransactionNameSourceTask
};

@class SentrySpanId;
@protocol SentrySpan;

typedef NS_ENUM(NSUInteger, SentrySpanStatus);

@interface SentryPerformanceTracker : SENTRY_BASE_OBJECT

@property (nonatomic, class, readonly) SentryPerformanceTracker *shared;

- (SentrySpanId *)startSpanWithName:(NSString *)name operation:(NSString *)operation;

- (SentrySpanId *)startSpanWithName:(NSString *)name
                         nameSource:(SentryTransactionNameSource)source
                          operation:(NSString *)operation
                             origin:(NSString *)origin;

- (void)activateSpan:(SentrySpanId *)spanId duringBlock:(void (^)(void))block;

- (void)measureSpanWithDescription:(NSString *)description
                         operation:(NSString *)operation
                            origin:(NSString *)origin
                           inBlock:(void (^)(void))block;

- (void)measureSpanWithDescription:(NSString *)description
                         operation:(NSString *)operation
                            origin:(NSString *)origin
                      parentSpanId:(SentrySpanId *)parentSpanId
                           inBlock:(void (^)(void))block;

- (nullable SentrySpanId *)activeSpanId;

- (void)finishSpan:(SentrySpanId *)spanId;

- (void)finishSpan:(SentrySpanId *)spanId withStatus:(SentrySpanStatus)status;

- (BOOL)isSpanAlive:(SentrySpanId *)spanId;

- (nullable id<SentrySpan>)getSpan:(SentrySpanId *)spanId;

- (BOOL)pushActiveSpan:(SentrySpanId *)spanId;

- (void)popActiveSpan;

@end

NS_ASSUME_NONNULL_END
