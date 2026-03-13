#import "SentryDefines.h"

@protocol SentrySpan;
@class SentryTracer;
@class SentryAppStartMeasurement;

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

/**
 * Builds app start spans for a UIViewController transaction. An intermediate grouping span
 * ("Cold Start" / "Warm Start") is inserted as parent for the phase spans:
 *
 * @code
 *   UIViewController (op: ui.load)            ← tracer
 *     └─ Cold Start (op: app.start.cold)      ← grouping span
 *          ├─ Pre Runtime Init
 *          ├─ Runtime Init to Pre Main Initializers
 *          ├─ UIKit Init
 *          ├─ Application Init
 *          └─ Initial Frame Render
 * @endcode
 */
NSArray<id<SentrySpan>> *sentryBuildAppStartSpans(
    SentryTracer *tracer, SentryAppStartMeasurement *_Nullable appStartMeasurement);

/**
 * Builds app start spans for a standalone app start transaction. Phase spans are parented
 * directly to the tracer (no intermediate grouping span):
 *
 * @code
 *   App Start Cold (op: app.start.cold)       ← tracer
 *     ├─ Pre Runtime Init
 *     ├─ Runtime Init to Pre Main Initializers
 *     ├─ UIKit Init
 *     ├─ Application Init
 *     └─ Initial Frame Render
 * @endcode
 */
NSArray<id<SentrySpan>> *sentryBuildStandaloneAppStartSpans(
    SentryTracer *tracer, SentryAppStartMeasurement *_Nullable appStartMeasurement);

#endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_END
