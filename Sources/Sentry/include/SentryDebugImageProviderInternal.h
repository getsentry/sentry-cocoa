#import <Foundation/Foundation.h>

@class SentryDebugMeta;
@class SentryBinaryImageCache;
@class SentryThread;
@class SentryFrame;

NS_ASSUME_NONNULL_BEGIN

@interface SentryDebugImageProviderInternal : NSObject

- (instancetype)init;

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

- (NSArray<SentryDebugMeta *> *)getDebugImagesFromCache;

@end

NS_ASSUME_NONNULL_END
