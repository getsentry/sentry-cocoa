#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif
#import SENTRY_HEADER(SentryProfilingConditionals)

NS_ASSUME_NONNULL_BEGIN

@class SentryDsn;
@class SentryHttpStatusCodeRange;
@class SentryMeasurementValue;
@class SentryReplayOptions;
#if SENTRY_TARGET_PROFILING_SUPPORTED
@class SentryProfileOptions;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
@class SentryScope;

@interface SentryOptionsInternal : NSObject

+ (NSArray<NSString *> *)defaultIntegrations

    @end

    NS_ASSUME_NONNULL_END
