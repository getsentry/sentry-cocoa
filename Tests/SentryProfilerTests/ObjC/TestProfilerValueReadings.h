#import "SentryProfilerTestConditionals.h"
#import "SentryProfilingSystemMetrics.h"
#import <Foundation/Foundation.h>

#if SENTRY_PROFILER_TESTS_SUPPORTED
@interface TestProfilerValueReadings : NSObject
@property (nonatomic) BOOL failReadings;
- (SentryProfilingSystemMetrics *_Nonnull)systemMetrics;
@end
#endif
