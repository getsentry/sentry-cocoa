#import "SentryDefines.h"

@class SentryTracer;
@class SentrySpanInternal;
@class SentryAppStartMeasurement;

NS_ASSUME_NONNULL_BEGIN

#if SENTRY_HAS_UIKIT

NSArray<SentrySpanInternal *> *sentryBuildAppStartSpans(
    SentryTracer *tracer, SentryAppStartMeasurement *_Nullable appStartMeasurement);

#endif // SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_END
