#import "SentryIntegrationProtocol.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryScope, SentryCrashWrapper;

static NSString *const SentryDeviceContextFreeMemoryKey = @"free_memory";

@interface SentryCrashIntegration : NSObject <SentryIntegrationProtocol>

+ (void)enrichScope:(SentryScope *)scope crashWrapper:(SentryCrashWrapper *)crashWrapper;

@end

NS_ASSUME_NONNULL_END
