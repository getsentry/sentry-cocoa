#import "SentryCrashDynamicLinker.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
  A wrapper around SentryCrash for testability.
 */
@protocol SentryCrashBinaryImageProvider <NSObject>

- (NSInteger)getImageCount;

- (SentryCrashBinaryImage)getBinaryImage:(NSInteger)index isCrash:(BOOL)isCrash;

@end

NS_ASSUME_NONNULL_END
