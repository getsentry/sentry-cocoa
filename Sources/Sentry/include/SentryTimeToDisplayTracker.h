#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

@class SentrySpan, SentryTracer, SentryFramesTracker;

NS_ASSUME_NONNULL_BEGIN

/**
 * This is a SentryTracer extension responsible for creating
 * TTID and TTFD spans.
 * This extension creates the TTID span during installation and make use of
 * the `SentryTracer` wait for children feature to keep transaction open long
 * enough to wait for a full display report if required, otherwise it finished
 * the TTID span when a initial display is registered, allowing the tracer to
 * finish as soon as possible.
 * TTFD span is created when `SentryTracer` request for additional spans only if
 * a full display was registered before.
 */
@interface SentryTimeToDisplayTracker : NSObject
SENTRY_NO_INIT

@property (nullable, nonatomic, strong, readonly) SentrySpan *initialDisplaySpan;

@property (nullable, nonatomic, strong, readonly) SentrySpan *fullDisplaySpan;

@property (nonatomic, readonly) BOOL waitForFullDisplay;

- (instancetype)initForController:(UIViewController *)controller
               waitForFullDisplay:(BOOL)waitForFullDisplay;

- (instancetype)initForController:(UIViewController *)controller
                     frameTracker:(SentryFramesTracker *)frametracker
               waitForFullDisplay:(BOOL)waitForFullDisplay;

- (void)startForTracer:(SentryTracer *)tracer;

- (void)reportReadyToDisplay;

- (void)reportFullyDisplayed;

@end

NS_ASSUME_NONNULL_END

#endif
