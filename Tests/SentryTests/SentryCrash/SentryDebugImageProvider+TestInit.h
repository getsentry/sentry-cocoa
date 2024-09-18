#import "SentryDebugImageProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryDebugImageProvider (TestInit)
- (instancetype)initWithBinaryImageProvider:(id<SentryCrashBinaryImageProvider>)binaryImageProvider;

@end

NS_ASSUME_NONNULL_END
