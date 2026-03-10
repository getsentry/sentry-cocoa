#import "SentryDefines.h"

@protocol SentrySpan;
@class SentryTracer;
@class SentryAppStartMeasurement;

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

NSArray<id<SentrySpan>> *sentryBuildAppStartSpans(
    SentryTracer *tracer, SentryAppStartMeasurement *_Nullable appStartMeasurement);

#endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_END
