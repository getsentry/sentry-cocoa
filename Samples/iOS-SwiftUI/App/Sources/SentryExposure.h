#import <Foundation/Foundation.h>

@class SentryTransactionContext;
@class SentrySpanId;
@protocol SentrySpan;

NS_ASSUME_NONNULL_BEGIN

@interface SentryTracer : NSObject

@property (nonatomic, strong) SentryTransactionContext *transactionContext;

@property (nonatomic, readonly) NSArray<id<SentrySpan>> *children;

@end

@interface SentryPerformanceTracker : NSObject

@property (nonatomic, class, readonly) SentryPerformanceTracker *shared;

- (nullable SentrySpanId *)activeSpanId;

- (nullable id<SentrySpan>)getSpan:(SentrySpanId *)spanId;

@end

NS_ASSUME_NONNULL_END
