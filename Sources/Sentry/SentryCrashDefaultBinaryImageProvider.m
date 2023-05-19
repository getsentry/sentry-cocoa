#import "SentryCrashDefaultBinaryImageProvider.h"
#import "SentryCrashBinaryImageProvider.h"
#import "SentryCrashDynamicLinker.h"
#import <Foundation/Foundation.h>

@implementation SentryCrashDefaultBinaryImageProvider

- (NSInteger)getImageCount
{
    return sentrycrashdl_imageCount();
}

- (SentryCrashBinaryImage)getBinaryImage:(NSInteger)index
{
    // maintains previous behavior for the same method call by also trying to gather crash info
    return [self getBinaryImage:index isCrash:YES];
}

- (SentryCrashBinaryImage)getBinaryImage:(NSInteger)index isCrash:(BOOL)isCrash
{
    SentryCrashBinaryImage image = { 0 };
    sentrycrashdl_getBinaryImage((int)index, &image, isCrash);
    return image;
}

@end
