/**
 * SentrySwiftUI needs a class from Sentry that is not public.
 * The easiest way do expose this class is by copying it interface.
 * We could just add the original header file to SwntrySwiftUI project,
 * but the original file has reference to other header that we don't need here.
 */

#import <Foundation/Foundation.h>

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

@interface SentryPerformanceTracker : NSObject

@property (nonatomic, class, readonly) SentryPerformanceTracker *shared;

- (SentrySpanId *)startSpanWithName:(NSString *)name operation:(NSString *)operation;
- (SentrySpanId *)startSpanWithName:(NSString *)name
                         nameSource:(SentryTransactionNameSource)source
                          operation:(NSString *)operation;

- (void)activateSpan:(SentrySpanId *)spanId duringBlock:(void (^)(void))block;

- (void)measureSpanWithDescription:(NSString *)description
                         operation:(NSString *)operation
                           inBlock:(void (^)(void))block;

- (void)measureSpanWithDescription:(NSString *)description
                         operation:(NSString *)operation
                      parentSpanId:(SentrySpanId *)parentSpanId
                           inBlock:(void (^)(void))block;

- (nullable SentrySpanId *)activeSpanId;

- (void)finishSpan:(SentrySpanId *)spanId;

- (void)finishSpan:(SentrySpanId *)spanId withStatus:(SentrySpanStatus)status;

- (BOOL)isSpanAlive:(SentrySpanId *)spanId;

- (nullable id<SentrySpan>)getSpan:(SentrySpanId *)spanId;

- (BOOL)pushActiveSpan:(SentrySpanId *)spanId;

- (void)popActiveSpan;

- (void)cancelSpan:(SentrySpanId *)spanId;

@end

NS_ASSUME_NONNULL_END
