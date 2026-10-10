#import "Wrappers/SentryPerformanceTrackerWrapper.h"

#if __has_include("SentryPerformanceTracker.h")
#    import "SentryPerformanceTracker.h"
#else
#    import "SentrySwift.h"
#endif

@interface SentryPerformanceTracker (TestAccess)
- (void)clear;
@end

void
wrapper_clearPerformanceTracker(void)
{
    [SentryPerformanceTracker.shared clear];
}
