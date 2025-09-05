#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryScreenFrames;

@interface SentryProfilingScreenFramesHelper : NSObject
+ (SentryScreenFrames *)copyScreenFrames:(SentryScreenFrames *)screenFrames;
@end

NS_ASSUME_NONNULL_END
