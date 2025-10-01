#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

@class SentryTracer;
@class SentryDispatchQueueWrapper;
@class UIViewController;

@protocol SentrySpan;

NS_ASSUME_NONNULL_BEGIN

/**
 * @brief This is a class responsible for creating
 * TTID and TTFD spans.
 * @discussion This class creates the TTID and TTFD spans and make use of
 * the @c SentryTracer wait for children feature to keep transaction open long
 * enough to wait for a full display report if @c waitForFullDisplay is true.
 */
@interface SentryTimeToDisplayTracker : NSObject
SENTRY_NO_INIT

@property (nullable, nonatomic, weak, readonly) id<SentrySpan> initialDisplaySpan;

@property (nullable, nonatomic, weak, readonly) id<SentrySpan> fullDisplaySpan;

@property (nonatomic, readonly) BOOL waitForFullDisplay;

- (instancetype)initWithName:(NSString *)name
          waitForFullDisplay:(BOOL)waitForFullDisplay
        dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper;

- (BOOL)startForTracer:(SentryTracer *)tracer;

- (void)reportInitialDisplay;

- (void)reportFullyDisplayed;

- (void)finishSpansIfNotFinished;

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
