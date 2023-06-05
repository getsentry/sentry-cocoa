#import "SentryBinaryImageCache.h"
#import "SentryCrashBinaryImageCache.h"

@interface
SentryBinaryImageCache ()

@property (nonatomic, strong) NSArray<BinaryImageInfo *> *cache;

- (void)binaryImageAdded:(const SentryCrashBinaryImage *)image;

- (void)binaryImageRemoved:(const SentryCrashBinaryImage *)image;

@end
