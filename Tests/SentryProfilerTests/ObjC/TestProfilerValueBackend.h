#import "SentryProfilerTestConditionals.h"
#if SENTRY_PROFILER_TESTS_SUPPORTED
#    import "SentryDependencyContainerSwiftHelper.h"
#    import "TestProfilerValueClock.h"
#    import "TestProfilerValueReadings.h"
NS_ASSUME_NONNULL_BEGIN
@interface TestProfilerValueBackend : SentryDefaultProfilerSDKBackend
@property (nonatomic, strong) TestProfilerValueClock *clock;
@property (nonatomic, strong) TestProfilerValueReadings *metrics;
@property (nonatomic, strong, nullable) NSTimer *lastTimer;
#    if SENTRY_HAS_UIKIT
@property (nonatomic, strong, nullable) SentryScreenFrames *frames;
#    endif
@end
NS_ASSUME_NONNULL_END
#endif
