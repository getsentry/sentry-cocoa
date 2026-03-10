#import "SentryDefines.h"

@protocol SentrySpan;
@class SentryTracer;
@class SentryAppStartMeasurement;

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

/**
 * Builds app start child spans and attaches them under an intermediate grouping span
 * ("Cold Start" / "Warm Start") parented to the tracer. Used when app start data is
 * attached to a UIViewController transaction.
 */
NSArray<id<SentrySpan>> *sentryBuildAppStartSpans(
    SentryTracer *tracer, SentryAppStartMeasurement *_Nullable appStartMeasurement);

/**
 * Builds app start child spans parented directly to the tracer, without the intermediate
 * grouping span. Used for standalone app start transactions where the transaction itself
 * represents the app start.
 */
NSArray<id<SentrySpan>> *sentryBuildStandaloneAppStartSpans(
    SentryTracer *tracer, SentryAppStartMeasurement *_Nullable appStartMeasurement);

#endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_END
