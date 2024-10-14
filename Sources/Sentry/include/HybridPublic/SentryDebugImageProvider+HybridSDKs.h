#import "SentryDebugImageProvider.h"

@class SentryDebugMeta;
@class SentryThread;
@class SentryFrame;

NS_ASSUME_NONNULL_BEGIN

@interface SentryDebugImageProvider ()

/**
 * Returns a list of debug images that are being referenced by the given frames.
 * This function uses the @c SentryBinaryImageCache which is significantly faster than @c
 * SentryCrashDefaultBinaryImageProvider for retrieving binary image information.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImagesFromCacheForFrames:(NSArray<SentryFrame *> *)frames
    NS_SWIFT_NAME(getDebugImagesFromCacheForFrames(frames:));

/**
 * Returns a list of debug images that are being referenced in the given threads.
 * This function uses the @c SentryBinaryImageCache which is significantly faster than @c
 * SentryCrashDefaultBinaryImageProvider for retrieving binary image information.
 */
- (NSArray<SentryDebugMeta *> *)getDebugImagesFromCacheForThreads:(NSArray<SentryThread *> *)threads
    NS_SWIFT_NAME(getDebugImagesFromCacheForThreads(threads:));

@end

NS_ASSUME_NONNULL_END
