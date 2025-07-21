/**
 * SentrySwiftUI needs a class from Sentry that is not public.
 * The easiest way do expose this class is by copying it interface.
 * We could just add the original header file to SwntrySwiftUI project,
 * but the original file has reference to other header that we don't need here.
 */

#import <Foundation/Foundation.h>

#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/Sentry.h>
#elif __has_include("Sentry.h")
#    import "Sentry.h"
#endif

#if SENTRY_TEST
#    import "SentrySpan.h"
#    import "SentryTracer.h"
#else
@class SentrySpan;
@interface SentryTracer : NSObject <SentrySpan>
@end
#endif

NS_ASSUME_NONNULL_BEGIN

extern NSString *const SENTRY_XCODE_PREVIEW_ENVIRONMENT_KEY;

typedef NS_ENUM(NSInteger, SentryTransactionNameSource);

@class SentrySpanId;
@class SentryDispatchQueueWrapper;

typedef NS_ENUM(NSUInteger, SentrySpanStatus);

@interface SentryPerformanceTracker : NSObject

@property (nonatomic, class, readonly) SentryPerformanceTracker *shared;

- (SentrySpanId *)startSpanWithName:(NSString *)name
                         nameSource:(SentryTransactionNameSource)source
                          operation:(NSString *)operation
                             origin:(NSString *)origin;

- (void)activateSpan:(SentrySpanId *)spanId duringBlock:(void (^)(void))block;

- (void)measureSpanWithDescription:(NSString *)description
                        nameSource:(SentryTransactionNameSource)source
                         operation:(NSString *)operation
                            origin:(NSString *)origin
                           inBlock:(void (^)(void))block;

- (void)measureSpanWithDescription:(NSString *)description
                        nameSource:(SentryTransactionNameSource)source
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

@interface SentryTimeToDisplayTracker : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nullable, nonatomic, weak, readonly) SentrySpan *initialDisplaySpan;

@property (nullable, nonatomic, weak, readonly) SentrySpan *fullDisplaySpan;

@property (nonatomic, readonly) BOOL waitForFullDisplay;

- (instancetype)initWithName:(NSString *)name
          waitForFullDisplay:(BOOL)waitForFullDisplay
        dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

- (instancetype)initWithName:(NSString *)name waitForFullDisplay:(BOOL)waitForFullDisplay;

- (BOOL)startForTracer:(SentryTracer *)tracer;

- (void)reportInitialDisplay;

- (void)reportFullyDisplayed;

- (void)finishSpansIfNotFinished;

@end

@interface SentryUIViewControllerPerformanceTracker : NSObject

- (void)reportFullyDisplayed;

- (nullable SentryTimeToDisplayTracker *)startTimeToDisplayTrackerForScreen:(NSString *)screenName
                                                         waitForFullDisplay:(BOOL)waitForFullDisplay
                                                                     tracer:(SentryTracer *)tracer;

@end

@interface SentrySDKInternal : NSObject
@property (nonatomic, nullable, readonly, class) SentryOptions *options;
@end

NS_ASSUME_NONNULL_END
