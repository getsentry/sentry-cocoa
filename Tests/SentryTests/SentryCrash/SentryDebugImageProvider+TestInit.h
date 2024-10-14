#import "SentryDebugImageProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryDebugImageProvider (TestInit)

- (instancetype)initWithBinaryImageProvider:(id<SentryCrashBinaryImageProvider>)binaryImageProvider
                           binaryImageCache:(SentryBinaryImageCache *)binaryImageCache;

@end

NS_ASSUME_NONNULL_END
