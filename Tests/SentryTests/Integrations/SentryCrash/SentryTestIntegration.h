#import "SentryIntegrationProtocol.h"
#import <Foundation/Foundation.h>

@class SentryOptions;

NS_ASSUME_NONNULL_BEGIN

@interface SentryTestIntegration : NSObject <SentryIntegrationProtocol>

@property (nonatomic, strong) SentryOptions *options;

@end

NS_ASSUME_NONNULL_END
