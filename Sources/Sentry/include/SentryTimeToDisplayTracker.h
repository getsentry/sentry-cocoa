#import "SentryDefines.h"
#import "SentryTracerExtension.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>

@class SentrySpan;

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
@interface SentryTimeToDisplayTracker : NSObject <SentryTracerExtension>
SENTRY_NO_INIT

@property (nonatomic, strong, readonly) NSDate *startDate;

@property (nonatomic, readonly) BOOL waitFullDisplay;

- (instancetype)initForController:(UIViewController *)controller
               waitForFullDisplay:(BOOL)waitFullDisplay;

- (void)reportInitialDisplay;

- (void)reportFullDisplay;

- (void)stopWaitingFullDisplay;

@end

NS_ASSUME_NONNULL_END

#endif
