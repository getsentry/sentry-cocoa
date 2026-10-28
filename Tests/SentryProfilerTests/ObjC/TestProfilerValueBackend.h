#import "SentryProfilerTestConditionals.h"
#if SENTRY_PROFILER_TESTS_SUPPORTED
#    import "SentryDefaultProfilerSDKBackend.h"
#    import "TestProfilerValueReadings.h"
NS_ASSUME_NONNULL_BEGIN
@interface TestProfilerValueBackend : SentryDefaultProfilerSDKBackend
@property (nonatomic, strong) TestProfilerValueReadings *metrics;
@end
NS_ASSUME_NONNULL_END
#endif
