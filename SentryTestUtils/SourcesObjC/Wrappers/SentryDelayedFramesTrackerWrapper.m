#import "Wrappers/SentryDelayedFramesTrackerWrapper.h"

#if SENTRY_HAS_UIKIT
#    import "SentrySwift.h"

@implementation TestDelayedWrapper
- (instancetype)initWithKeepDelayedFramesDuration:(CFTimeInterval)keepDelayedFramesDuration
                                     dateProvider:(id)dateProvider
{
    return [super initWithKeepDelayedFramesDuration:keepDelayedFramesDuration
                                       dateProvider:(id<SentryCurrentDateProvider>)dateProvider];
}
@end
#endif
