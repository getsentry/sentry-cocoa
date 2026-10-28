#import "SentryProfilerTestConditionals.h"
#if SENTRY_PROFILER_TESTS_SUPPORTED
#    if SWIFT_PACKAGE
#        import "SentrySwift.h"
#    else
@import Sentry;
#    endif
@interface TestProfilerValueClock : NSObject <SentryCurrentDateProvider>
@end
#endif
