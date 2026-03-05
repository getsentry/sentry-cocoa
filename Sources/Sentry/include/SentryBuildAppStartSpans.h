#import "SentryDefines.h"

@protocol SentrySpan;
@class SentryTracer;
@class SentryAppStartMeasurement;

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

NSArray<SentrySpanInternal *> *sentryBuildAppStartSpans(
    SentryTracer *tracer, SentryAppStartMeasurement *_Nullable appStartMeasurement,
    BOOL isStandaloneAppStartTransaction);

#endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_END
