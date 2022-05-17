#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryBenchmarking : NSObject

+ (void)startBenchmarkProfile;
+ (double)retrieveBenchmarks;

@end

NS_ASSUME_NONNULL_END
