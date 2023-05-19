#import "SentryCrashDynamicLinker.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
  A wrapper around SentryCrash for testability.
 */
@protocol SentryCrashBinaryImageProvider <NSObject>

- (NSInteger)getImageCount;

/**
 * @warning This assumes a crash has occurred and attempts to read the crash information from the
 * image's data segment, which may not be present or be invalid if a crash has not actually
 * occurred. To avoid this, use the new @c -[getDebugImage:isCrash:] instead.
 */
- (SentryCrashBinaryImage)getBinaryImage:(NSInteger)index;

/**
 * Returns information for the image at the specified index.
 * @param isCrash @c YES if we're collecting binary images for a crash report, @c NO if we're
 * gathering them for other backtrace information, like a performance transaction. If this is for a
 * crash, each image's data section crash info is also included.
 */
- (SentryCrashBinaryImage)getBinaryImage:(NSInteger)index isCrash:(BOOL)isCrash;

@end

NS_ASSUME_NONNULL_END
