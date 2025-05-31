#import "ThreadInfoHelper.h"
#import "SentryThread.h"
#include "SentryThreadHandle.hpp"

#if SENTRY_TARGET_PROFILING_SUPPORTED

@implementation ThreadInfoHelper

+ (SentryThread *)threadInfo
{
    const auto threadID = sentry::profiling::ThreadHandle::current()->tid();
    return [[SentryThread alloc] initWithThreadId:@(threadID)];
}

@end

#endif
