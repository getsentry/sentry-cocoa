#import "SentryDefines.h"
#import "SentryTracerMiddleware.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

@class SentrySpan;

NS_ASSUME_NONNULL_BEGIN

/**
 * This is a SentryTracer middleware responsible for creating
 * TTID and TTFD spans.
 * This middleware creates the TTID span during installation and make use of
 * the `SentryTracer` wait for children feature to keep transaction open long
 * enough to wait for a full display report if required, otherwise it finished
 * the TTID span when a initial display is registered, allowing the tracer to
 * finish as soon as possible.
 * TTFD span is created when `SentryTracer` request for additional spans only if
 * a full display was registered before.
 */
@interface SentryTimeToDisplayTracker : NSObject <SentryTracerMiddleware>
SENTRY_NO_INIT

@property (nonatomic, strong, readonly) NSDate *startDate;

- (instancetype)initForController:(UIViewController *)controller
               waitForFullDisplay:(BOOL)waitFullDisplay;

- (void)registerInitialDisplay;

- (void)registerFullDisplay;

- (void)stopWaitingFullDisplay;

@end

NS_ASSUME_NONNULL_END

#endif
