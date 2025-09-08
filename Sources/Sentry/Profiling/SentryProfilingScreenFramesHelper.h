#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@class SentryScreenFrames;

// Helper to use SentryScreenFrames without importing Swift on ObjC++ files.
@interface SentryProfilingScreenFramesHelper : NSObject
+ (SentryScreenFrames *)copyScreenFrames:(SentryScreenFrames *)screenFrames;
@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
