#import "SentryProfilingScreenFramesHelper.h"
#import "SentrySwift.h"

#if SENTRY_HAS_UIKIT

@implementation SentryProfilingScreenFramesHelper

+ (SentryScreenFrames *)copyScreenFrames:(SentryScreenFrames *)screenFrames
{
    return [screenFrames copy];
}

@end

#endif // SENTRY_HAS_UIKIT
