#import "SentryProfilingScreenFramesHelper.h"
#import "SentrySwift.h"

@implementation SentryProfilingScreenFramesHelper

+ (SentryScreenFrames *)copyScreenFrames:(SentryScreenFrames *)screenFrames
{
    return [screenFrames copy];
}

@end
